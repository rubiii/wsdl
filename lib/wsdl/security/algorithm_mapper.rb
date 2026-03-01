# frozen_string_literal: true

module WSDL
  module Security
    # Maps XML Digital Signature algorithm URIs to internal symbols.
    #
    # This module centralizes the logic for converting algorithm URIs
    # found in XML signatures to the symbols used by Canonicalizer,
    # Digester, and other internal classes.
    #
    # **Security:** This module raises {UnsupportedAlgorithmError} for
    # unknown or missing algorithms. It never silently defaults to a
    # fallback algorithm, as this could mask algorithm confusion attacks.
    #
    # @example Map a digest algorithm
    #   AlgorithmMapper.digest_algorithm('http://www.w3.org/2001/04/xmlenc#sha256')
    #   # => :sha256
    #
    # @example Handle unknown algorithm
    #   AlgorithmMapper.digest_algorithm('http://attacker.com/fake')
    #   # => raises UnsupportedAlgorithmError
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    # @see https://www.w3.org/TR/xmldsig-bestpractices/
    #
    module AlgorithmMapper
      # Canonicalization algorithm URI patterns to symbols.
      # Order matters: more specific patterns (with comments) must come first.
      C14N_MAPPINGS = [
        # Exclusive C14N 1.0
        [/xml-exc-c14n#WithComments/i, :exclusive_1_0_with_comments],
        [/xml-exc-c14n/i, :exclusive_1_0],
        # Canonical XML 1.1
        [/xml-c14n11#WithComments/i, :inclusive_1_1_with_comments],
        [/xml-c14n11/i, :inclusive_1_1],
        # Canonical XML 1.0
        [/REC-xml-c14n-20010315#WithComments/i, :inclusive_1_0_with_comments],
        [/REC-xml-c14n-20010315/i, :inclusive_1_0]
      ].freeze

      # Digest algorithm URI patterns to symbols.
      # Order matters: longer matches (sha512) must come before shorter (sha1).
      DIGEST_MAPPINGS = [
        [/sha512/i, :sha512],
        [/sha384/i, :sha384],
        [/sha256/i, :sha256],
        [/sha224/i, :sha224],
        [/sha1/i, :sha1]
      ].freeze

      # Signature algorithm URI patterns to OpenSSL digest names.
      # Supports RSA, ECDSA, and DSA algorithms.
      # Order matters: longer matches must come before shorter ones.
      SIGNATURE_DIGEST_MAPPINGS = [
        # RSA algorithms
        [/rsa-sha512/i, 'SHA512'],
        [/rsa-sha384/i, 'SHA384'],
        [/rsa-sha256/i, 'SHA256'],
        [/rsa-sha224/i, 'SHA224'],
        [/rsa-sha1/i, 'SHA1'],
        # ECDSA algorithms
        [/ecdsa-sha512/i, 'SHA512'],
        [/ecdsa-sha384/i, 'SHA384'],
        [/ecdsa-sha256/i, 'SHA256'],
        [/ecdsa-sha224/i, 'SHA224'],
        [/ecdsa-sha1/i, 'SHA1'],
        # DSA algorithms (legacy)
        [/dsa-sha256/i, 'SHA256'],
        [/dsa-sha1/i, 'SHA1']
      ].freeze

      class << self
        # Maps a canonicalization algorithm URI to an internal symbol.
        #
        # For canonicalization, a nil or empty URI defaults to Exclusive C14N 1.0,
        # which is the most commonly used and safest default for WS-Security.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [Symbol] the canonicalization algorithm symbol
        # @raise [UnsupportedAlgorithmError] if the URI is not recognized
        #
        # @example
        #   AlgorithmMapper.c14n_algorithm('http://www.w3.org/2001/10/xml-exc-c14n#')
        #   # => :exclusive_1_0
        #
        def c14n_algorithm(uri)
          # Default to Exclusive C14N when not specified (safe default)
          return :exclusive_1_0 if uri.nil? || uri.empty?

          find_algorithm(uri, C14N_MAPPINGS) ||
            raise_unsupported(:canonicalization, uri)
        end

        # Maps a digest algorithm URI to an internal symbol.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [Symbol] the digest algorithm symbol
        # @raise [UnsupportedAlgorithmError] if the URI is nil, empty, or not recognized
        #
        # @example
        #   AlgorithmMapper.digest_algorithm('http://www.w3.org/2001/04/xmlenc#sha256')
        #   # => :sha256
        #
        def digest_algorithm(uri)
          raise_missing(:digest) if uri.nil? || uri.empty?

          find_algorithm(uri, DIGEST_MAPPINGS) ||
            raise_unsupported(:digest, uri)
        end

        # Maps a signature algorithm URI to an OpenSSL digest name.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [String] the OpenSSL digest name (e.g., 'SHA256')
        # @raise [UnsupportedAlgorithmError] if the URI is nil, empty, or not recognized
        #
        # @example
        #   AlgorithmMapper.signature_digest('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
        #   # => 'SHA256'
        #
        def signature_digest(uri)
          raise_missing(:signature) if uri.nil? || uri.empty?

          find_algorithm(uri, SIGNATURE_DIGEST_MAPPINGS) ||
            raise_unsupported(:signature, uri)
        end

        # Checks if an algorithm URI is supported without raising.
        #
        # @param uri [String] the algorithm URI
        # @param type [Symbol] the algorithm type (:digest, :signature, :canonicalization)
        # @return [Boolean] true if the algorithm is supported
        #
        # @example
        #   AlgorithmMapper.supported?('http://www.w3.org/2001/04/xmlenc#sha256', type: :digest)
        #   # => true
        #
        #   AlgorithmMapper.supported?('http://unknown/alg', type: :digest)
        #   # => false
        #
        def supported?(uri, type:)
          return false if uri.nil? || uri.empty?

          mappings = case type
          when :digest then DIGEST_MAPPINGS
          when :signature then SIGNATURE_DIGEST_MAPPINGS
          when :canonicalization then C14N_MAPPINGS
          else return false
          end

          !find_algorithm(uri, mappings).nil?
        end

        private

        # Finds an algorithm in the mappings.
        #
        # @param uri [String] the URI to match
        # @param mappings [Array<Array(Regexp, Object)>] pattern/value pairs
        # @return [Object, nil] the matched value or nil
        #
        def find_algorithm(uri, mappings)
          mappings.each do |pattern, value|
            return value if uri.match?(pattern)
          end
          nil
        end

        # Raises an error for missing algorithm specification.
        #
        # @param type [Symbol] the algorithm type
        # @raise [UnsupportedAlgorithmError]
        #
        def raise_missing(type)
          raise UnsupportedAlgorithmError.new(
            "Missing #{type} algorithm specification in signature",
            algorithm_type: type
          )
        end

        # Raises an error for unsupported algorithm.
        #
        # @param type [Symbol] the algorithm type
        # @param uri [String] the unrecognized URI
        # @raise [UnsupportedAlgorithmError]
        #
        def raise_unsupported(type, uri)
          raise UnsupportedAlgorithmError.new(
            "Unsupported #{type} algorithm: #{uri}",
            algorithm_uri: uri,
            algorithm_type: type
          )
        end
      end
    end
  end
end
