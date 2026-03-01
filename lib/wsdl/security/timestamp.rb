# frozen_string_literal: true

require 'time'

class WSDL
  module Security
    # Represents a WS-Security Timestamp element.
    #
    # The Timestamp element provides freshness guarantees by including
    # creation and expiration times. It's commonly signed to prevent
    # replay attacks.
    #
    # @example Basic usage
    #   timestamp = Timestamp.new
    #   timestamp.to_xml(builder)
    #
    # @example With custom expiration
    #   timestamp = Timestamp.new(expires_in: 600) # 10 minutes
    #
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-SOAPMessageSecurity.pdf
    #
    class Timestamp
      # Default time-to-live in seconds (5 minutes)
      DEFAULT_TTL = 300

      # Returns the creation time.
      # @return [Time] the UTC creation time
      attr_reader :created_at

      # Returns the expiration time.
      # @return [Time] the UTC expiration time
      attr_reader :expires_at

      # Returns the unique ID for this timestamp element.
      # @return [String] the wsu:Id attribute value
      attr_reader :id

      # Creates a new Timestamp instance.
      #
      # @param created_at [Time, nil] the creation time (defaults to current UTC time)
      # @param expires_in [Integer] seconds until expiration (default: 300)
      # @param expires_at [Time, nil] explicit expiration time (overrides expires_in)
      # @param id [String, nil] the wsu:Id attribute (auto-generated if nil)
      #
      def initialize(created_at: nil, expires_in: DEFAULT_TTL, expires_at: nil, id: nil)
        @created_at = (created_at || Time.now).utc
        @expires_at = expires_at&.utc || (@created_at + expires_in)
        @id = id || IdGenerator.for('Timestamp')
      end

      # Returns the created timestamp as an XML Schema dateTime string.
      #
      # @return [String] ISO 8601 formatted timestamp
      #
      def created_at_xml
        @created_at.xmlschema
      end

      # Returns the expiration timestamp as an XML Schema dateTime string.
      #
      # @return [String] ISO 8601 formatted timestamp
      #
      def expires_at_xml
        @expires_at.xmlschema
      end

      # Checks if the timestamp has expired.
      #
      # @return [Boolean] true if the current time is past the expiration time
      #
      def expired?
        Time.now.utc > @expires_at
      end

      # Builds the XML representation of the Timestamp element.
      #
      # @param xml [Builder::XmlMarkup, Nokogiri::XML::Builder] the XML builder
      # @return [void]
      #
      # @example Output XML structure
      #   <wsu:Timestamp wsu:Id="Timestamp-abc123">
      #     <wsu:Created>2026-02-01T12:00:00Z</wsu:Created>
      #     <wsu:Expires>2026-02-01T12:05:00Z</wsu:Expires>
      #   </wsu:Timestamp>
      #
      def to_xml(xml)
        xml['wsu'].Timestamp('wsu:Id' => @id) do
          xml['wsu'].Created(created_at_xml)
          xml['wsu'].Expires(expires_at_xml)
        end
      end

      # Returns a Hash representation suitable for Gyoku XML generation.
      #
      # @return [Hash] the timestamp structure as a hash
      #
      def to_hash
        {
          'wsu:Timestamp' => {
            'wsu:Created' => created_at_xml,
            'wsu:Expires' => expires_at_xml,
            :attributes! => {
              'wsu:Timestamp' => { 'wsu:Id' => @id }
            },
            :order! => ['wsu:Created', 'wsu:Expires']
          }
        }
      end
    end
  end
end
