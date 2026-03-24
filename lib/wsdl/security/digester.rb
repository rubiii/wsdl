# frozen_string_literal: true

require 'openssl'
require 'base64'

module WSDL
  module Security
    # Handles digest calculation for XML Digital Signatures.
    #
    # The Digester computes cryptographic hashes of XML content for use
    # in signature Reference elements. It supports SHA-1, SHA-256, and
    # SHA-512 algorithms.
    #
    # @example Basic usage
    #   digester = Digester.new
    #   digest = digester.digest("content to hash")
    #
    # @example With Base64 encoding (for XML output)
    #   digester = Digester.new(algorithm: :sha256)
    #   base64_digest = digester.base64_digest(canonicalized_xml)
    #
    # @see https://www.w3.org/TR/xmldsig-core1/#sec-DigestMethod
    #
    class Digester
      # Local alias for digest algorithm constants
      Digest = Constants::Algorithms::Digest

      # Supported digest algorithms.
      #
      # Each algorithm specifies:
      # - :id - The URI used in XML DigestMethod elements
      # - :name - The OpenSSL digest name
      # - :klass - The OpenSSL::Digest class to use
      #
      ALGORITHMS = {
        # SHA-1 (legacy, still widely used in WS-Security)
        sha1: {
          id: Digest::SHA1,
          name: 'SHA1',
          klass: OpenSSL::Digest::SHA1
        },

        # SHA-224
        sha224: {
          id: Digest::SHA224,
          name: 'SHA224',
          klass: OpenSSL::Digest::SHA224
        },

        # SHA-256 (recommended)
        sha256: {
          id: Digest::SHA256,
          name: 'SHA256',
          klass: OpenSSL::Digest::SHA256
        },

        # SHA-384
        sha384: {
          id: Digest::SHA384,
          name: 'SHA384',
          klass: OpenSSL::Digest::SHA384
        },

        # SHA-512 (strongest)
        sha512: {
          id: Digest::SHA512,
          name: 'SHA512',
          klass: OpenSSL::Digest::SHA512
        }
      }.freeze

      # Default algorithm to use
      DEFAULT_ALGORITHM = :sha256

      # Returns the current algorithm configuration.
      # @return [Hash] the algorithm settings
      attr_reader :algorithm

      # Returns the algorithm symbol.
      # @return [Symbol] the algorithm key (e.g., :sha256)
      attr_reader :algorithm_key

      # Creates a new Digester instance.
      #
      # @param algorithm [Symbol] the digest algorithm to use
      #   (default: :sha256)
      #
      # @raise [ArgumentError] if an unknown algorithm is specified
      #
      def initialize(algorithm: DEFAULT_ALGORITHM)
        @algorithm_key = algorithm
        @algorithm = ALGORITHMS[algorithm] or
          raise ArgumentError, "Unknown digest algorithm: #{algorithm.inspect}. " \
                               "Valid options: #{ALGORITHMS.keys.join(', ')}"
      end

      # Computes the digest of the given data.
      #
      # @param data [String] the data to digest
      # @return [String] the raw binary digest
      #
      # @example
      #   digester.digest("hello world")
      #   # => binary string
      #
      def digest(data)
        @algorithm[:klass].digest(data)
      end

      # Computes the digest and returns it as a Base64-encoded string.
      #
      # This is the format required for XML DigestValue elements.
      #
      # @param data [String] the data to digest
      # @return [String] the Base64-encoded digest
      #
      # @example
      #   digester.base64_digest("hello world")
      #   # => "Kq5sNclPz7QV2+lfQIuc6R7oRu0="
      #
      def base64_digest(data)
        Base64.strict_encode64(digest(data))
      end

      # Computes the digest and returns it as a hexadecimal string.
      #
      # @param data [String] the data to digest
      # @return [String] the hexadecimal digest
      #
      def hex_digest(data)
        @algorithm[:klass].hexdigest(data)
      end

      # Returns the algorithm URI for use in XML DigestMethod elements.
      #
      # @return [String] the digest algorithm URI
      #
      def algorithm_id
        @algorithm[:id]
      end

      # Returns the OpenSSL digest name.
      #
      # @return [String] the digest algorithm name (e.g., 'SHA256')
      #
      def algorithm_name
        @algorithm[:name]
      end

      # Returns the digest length in bytes.
      #
      # @return [Integer] the digest length
      #
      def digest_length
        @algorithm[:klass].new.digest_length
      end

      # Creates a new OpenSSL::Digest instance for this algorithm.
      #
      # This is useful when you need to feed data incrementally
      # or when signing.
      #
      # @return [OpenSSL::Digest] a new digest instance
      #
      def new_digest
        @algorithm[:klass].new
      end

      # Class method to compute a digest with default settings.
      #
      # @param data [String] the data to digest
      # @param algorithm [Symbol] the algorithm to use (default: :sha256)
      # @param encode [Symbol, nil] encoding format (:base64, :hex, or nil for raw)
      #
      # @return [String] the digest in the specified format
      #
      def self.digest(data, algorithm: DEFAULT_ALGORITHM, encode: nil)
        digester = new(algorithm:)

        case encode
        when :base64
          digester.base64_digest(data)
        when :hex
          digester.hex_digest(data)
        else
          digester.digest(data)
        end
      end

      # Class method to compute a Base64-encoded digest.
      #
      # @param data [String] the data to digest
      # @param algorithm [Symbol] the algorithm to use (default: :sha256)
      #
      # @return [String] the Base64-encoded digest
      #
      def self.base64_digest(data, algorithm: DEFAULT_ALGORITHM)
        new(algorithm:).base64_digest(data)
      end
    end
  end
end
