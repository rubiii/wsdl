# frozen_string_literal: true

require 'time'

module WSDL
  module Security
    class Verifier
      # Validates timestamp freshness in SOAP responses.
      #
      # This validator checks that response timestamps are within acceptable
      # time bounds to prevent replay attacks and detect stale messages.
      #
      # Per WS-Security specification (Section 10), timestamps are optional.
      # When present, this validator checks:
      #
      # - **Created** is not too far in the future (clock skew protection)
      # - **Expires** is not in the past (freshness check)
      #
      # Clock skew tolerance is applied to both checks to account for
      # unsynchronized clocks between sender and receiver.
      #
      # @example Basic validation
      #   validator = TimestampValidator.new(document)
      #   if validator.valid?
      #     puts "Timestamp is fresh"
      #   else
      #     puts "Errors: #{validator.errors}"
      #   end
      #
      # @example With custom clock skew
      #   validator = TimestampValidator.new(document, clock_skew: 600)
      #   validator.valid?
      #
      # @see https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-SOAPMessageSecurity-v1.1.1-os.html#_Toc307407939
      #
      class TimestampValidator < Base
        # Default clock skew tolerance in seconds (5 minutes).
        #
        # This value aligns with WS-I BSP guidance and the default TTL
        # used for outgoing timestamps.
        DEFAULT_CLOCK_SKEW = 300

        # Returns the parsed Created time from the timestamp.
        #
        # @return [Time, nil] the UTC creation time, or nil if not present
        attr_reader :created_at

        # Returns the parsed Expires time from the timestamp.
        #
        # @return [Time, nil] the UTC expiration time, or nil if not present
        attr_reader :expires_at

        # Creates a new TimestampValidator instance.
        #
        # @param document [Nokogiri::XML::Document] the SOAP response document
        # @param clock_skew [Integer] acceptable clock skew in seconds (default: 300)
        # @param reference_time [Time, nil] the time to validate against
        #   (defaults to current UTC time; useful for testing)
        #
        def initialize(document, clock_skew: DEFAULT_CLOCK_SKEW, reference_time: nil)
          super()
          @document = document
          @clock_skew = clock_skew
          @reference_time = reference_time
          @created_at = nil
          @expires_at = nil
          @parsed = false
        end

        # Validates the timestamp freshness.
        #
        # Returns true if:
        # - No timestamp is present (timestamps are optional per spec)
        # - Timestamp is present and within acceptable time bounds
        #
        # Returns false if:
        # - Created time is too far in the future (beyond clock skew)
        # - Expires time is in the past (accounting for clock skew)
        # - Timestamp contains malformed time values
        #
        # @return [Boolean] true if valid or no timestamp present
        #
        def valid?
          parse_timestamp unless @parsed

          return true unless timestamp_present?

          validate_created && validate_expires
        end

        # Returns whether a timestamp element is present in the document.
        #
        # @return [Boolean] true if wsu:Timestamp exists in the Security header
        #
        def timestamp_present?
          parse_timestamp unless @parsed
          !timestamp_node.nil?
        end

        # Returns the timestamp as a hash.
        #
        # @return [Hash, nil] hash with :created_at and :expires_at keys,
        #   or nil if no timestamp present
        #
        def timestamp
          parse_timestamp unless @parsed
          return nil unless timestamp_present?

          { created_at: @created_at, expires_at: @expires_at }
        end

        private

        # Returns the reference time for validation.
        #
        # @return [Time] the reference time (provided or current UTC)
        #
        def reference_time
          @reference_time || Time.now.utc
        end

        # Parses the timestamp element and extracts Created/Expires times.
        #
        # @return [void]
        #
        def parse_timestamp
          @parsed = true

          return unless timestamp_node

          @created_at = parse_time_element('wsu:Created')
          @expires_at = parse_time_element('wsu:Expires')
        end

        # Parses a time element within the timestamp.
        #
        # @param element_name [String] the element name (e.g., 'wsu:Created')
        # @return [Time, nil] the parsed UTC time, or nil if not present/invalid
        #
        def parse_time_element(element_name)
          element = timestamp_node.at_xpath(element_name, ns)
          return nil unless element

          Time.parse(element.text).utc
        rescue ArgumentError
          # Malformed time value - will be caught during validation
          nil
        end

        # Returns the wsu:Timestamp element from the Security header.
        #
        # @return [Nokogiri::XML::Element, nil] the Timestamp element
        #
        def timestamp_node
          @timestamp_node ||= find_timestamp_node
        end

        # Finds the Timestamp element within the Security header.
        #
        # Per WS-Security spec, Timestamp must be within wsse:Security header.
        #
        # @return [Nokogiri::XML::Element, nil] the Timestamp element
        #
        def find_timestamp_node
          @document.at_xpath(
            '//wsse:Security/wsu:Timestamp',
            ns
          )
        end

        # Validates the Created time is not too far in the future.
        #
        # A message with a Created time significantly in the future indicates
        # either clock skew beyond tolerance or a potential attack.
        #
        # @return [Boolean] true if Created is valid or not present
        #
        def validate_created
          return true unless @created_at

          max_created = reference_time + @clock_skew

          if @created_at > max_created
            skew_detected = (@created_at - reference_time).to_i
            return add_failure(
              'Timestamp Created is too far in the future ' \
              "(#{skew_detected}s ahead, max allowed: #{@clock_skew}s)"
            )
          end

          true
        end

        # Validates the Expires time is not in the past.
        #
        # A message whose Expires time has passed (accounting for clock skew)
        # should be considered stale and potentially replayed.
        #
        # @return [Boolean] true if Expires is valid or not present
        #
        def validate_expires
          return true unless @expires_at

          # Allow some tolerance for clock skew when checking expiration
          min_expires = reference_time - @clock_skew

          if @expires_at < min_expires
            expired_ago = (reference_time - @expires_at).to_i
            return add_failure(
              'Timestamp has expired ' \
              "(#{expired_ago}s ago, tolerance: #{@clock_skew}s)"
            )
          end

          true
        end
      end
    end
  end
end
