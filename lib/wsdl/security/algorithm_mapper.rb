# frozen_string_literal: true

module WSDL
  module Security
    # Maps XML Digital Signature algorithm URIs to internal symbols.
    #
    # This module centralizes the logic for converting algorithm URIs
    # found in XML signatures to the symbols used by Canonicalizer,
    # Digester, and other internal classes.
    #
    # @example Map a canonicalization algorithm
    #   AlgorithmMapper.c14n_algorithm('http://www.w3.org/2001/10/xml-exc-c14n#')
    #   # => :exclusive_1_0
    #
    # @example Map a digest algorithm
    #   AlgorithmMapper.digest_algorithm('http://www.w3.org/2001/04/xmlenc#sha256')
    #   # => :sha256
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    #
    module AlgorithmMapper
      # Canonicalization algorithm URI patterns to symbols
      C14N_MAPPINGS = [
        [/REC-xml-c14n-20010315/, :inclusive_1_0],
        [/xml-c14n11/, :inclusive_1_1],
        [/xml-exc-c14n/, :exclusive_1_0]
      ].freeze

      # Digest algorithm URI patterns to symbols
      DIGEST_MAPPINGS = [
        [/sha512/i, :sha512],
        [/sha1/i, :sha1],
        [/sha256/i, :sha256]
      ].freeze

      # Signature algorithm URI patterns to OpenSSL digest names
      SIGNATURE_DIGEST_MAPPINGS = [
        [/rsa-sha512/i, 'SHA512'],
        [/rsa-sha1/i, 'SHA1'],
        [/rsa-sha256/i, 'SHA256']
      ].freeze

      class << self
        # Maps a canonicalization algorithm URI to an internal symbol.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [Symbol] the canonicalization algorithm symbol
        #
        # @example
        #   AlgorithmMapper.c14n_algorithm('http://www.w3.org/TR/2001/REC-xml-c14n-20010315')
        #   # => :inclusive_1_0
        #
        def c14n_algorithm(uri)
          match_algorithm(uri, C14N_MAPPINGS, default: :exclusive_1_0)
        end

        # Maps a digest algorithm URI to an internal symbol.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [Symbol] the digest algorithm symbol
        #
        # @example
        #   AlgorithmMapper.digest_algorithm('http://www.w3.org/2001/04/xmlenc#sha256')
        #   # => :sha256
        #
        def digest_algorithm(uri)
          match_algorithm(uri, DIGEST_MAPPINGS, default: :sha256)
        end

        # Maps a signature algorithm URI to an OpenSSL digest name.
        #
        # @param uri [String, nil] the algorithm URI
        # @return [String] the OpenSSL digest name
        #
        # @example
        #   AlgorithmMapper.signature_digest('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
        #   # => 'SHA256'
        #
        def signature_digest(uri)
          match_algorithm(uri, SIGNATURE_DIGEST_MAPPINGS, default: 'SHA256')
        end

        private

        # Matches a URI against a list of pattern/value pairs.
        #
        # @param uri [String, nil] the URI to match
        # @param mappings [Array<Array(Regexp, Object)>] pattern/value pairs
        # @param default [Object] the default value if no match
        # @return [Object] the matched value or default
        #
        def match_algorithm(uri, mappings, default:)
          return default unless uri

          mappings.each do |pattern, value|
            return value if uri.match?(pattern)
          end

          default
        end
      end
    end
  end
end
