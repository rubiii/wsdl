# frozen_string_literal: true

module WSDL
  module Security
    # Value object encapsulating signature configuration options.
    #
    # This class extracts and validates the various options that can be
    # passed to {Config#signature}, providing a clean interface for
    # accessing signature-related settings.
    #
    # @example Creating from a hash
    #   options = SignatureOptions.from_hash(
    #     sign_timestamp: true,
    #     sign_addressing: true,
    #     key_reference: :issuer_serial
    #   )
    #
    # @example Checking options
    #   options.sign_addressing?        # => true
    #   options.key_reference           # => :issuer_serial
    #
    class SignatureOptions
      # Default values for signature options
      DEFAULTS = {
        sign_timestamp: true,
        sign_addressing: false,
        explicit_namespace_prefixes: false,
        key_reference: Constants::KeyReference::BINARY_SECURITY_TOKEN,
        digest_algorithm: :sha256
      }.freeze

      # @return [Symbol] the digest algorithm (:sha1, :sha256, :sha512)
      attr_reader :digest_algorithm

      # @return [Symbol] the key reference method
      attr_reader :key_reference

      # Creates a new SignatureOptions instance.
      #
      # @param options [Hash] the signature options
      # @option options [Boolean] :sign_timestamp whether to sign the timestamp
      # @option options [Boolean] :sign_addressing whether to sign WS-Addressing headers
      # @option options [Boolean] :explicit_namespace_prefixes whether to use explicit ns prefixes
      # @option options [Symbol] :key_reference how to reference the signing certificate
      # @option options [Symbol] :digest_algorithm the digest algorithm to use
      #
      def initialize(**options)
        @sign_timestamp = options[:sign_timestamp]
        @sign_addressing = options[:sign_addressing]
        @explicit_namespace_prefixes = options[:explicit_namespace_prefixes]
        @key_reference = options[:key_reference]
        @digest_algorithm = options[:digest_algorithm]
      end

      # Creates a SignatureOptions instance from a hash of options.
      #
      # This method applies default values for any missing options.
      #
      # @param options [Hash] the options hash
      # @return [SignatureOptions] a new instance with the specified options
      #
      def self.from_hash(options)
        new(
          sign_timestamp: options.fetch(:sign_timestamp, DEFAULTS[:sign_timestamp]),
          sign_addressing: options.fetch(:sign_addressing, DEFAULTS[:sign_addressing]),
          explicit_namespace_prefixes: options.fetch(:explicit_namespace_prefixes,
                                                     DEFAULTS[:explicit_namespace_prefixes]),
          key_reference: options.fetch(:key_reference, DEFAULTS[:key_reference]),
          digest_algorithm: options.fetch(:digest_algorithm, DEFAULTS[:digest_algorithm])
        )
      end

      # Returns whether the timestamp should be signed.
      #
      # @return [Boolean]
      #
      def sign_timestamp?
        @sign_timestamp == true
      end

      # Returns whether WS-Addressing headers should be signed.
      #
      # @return [Boolean]
      #
      def sign_addressing?
        @sign_addressing == true
      end

      # Returns whether explicit namespace prefixes should be used.
      #
      # @return [Boolean]
      #
      def explicit_namespace_prefixes?
        @explicit_namespace_prefixes == true
      end

      # Returns a Hash representation of the options.
      #
      # @return [Hash] the options as a hash
      #
      def to_h
        {
          sign_timestamp: @sign_timestamp,
          sign_addressing: @sign_addressing,
          explicit_namespace_prefixes: @explicit_namespace_prefixes,
          key_reference: @key_reference,
          digest_algorithm: @digest_algorithm
        }
      end

      # Compares two SignatureOptions for equality.
      #
      # @param other [SignatureOptions] the other options
      # @return [Boolean] true if options are equal
      #
      def ==(other)
        return false unless other.is_a?(SignatureOptions)

        to_h == other.to_h
      end
      alias eql? ==

      # Returns a hash code for the options.
      #
      # @return [Integer] the hash code
      #
      def hash
        to_h.hash
      end
    end
  end
end
