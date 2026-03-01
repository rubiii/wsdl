# frozen_string_literal: true

require 'openssl'
require 'base64'
require_relative 'base'
require 'wsdl/security/canonicalizer'
require 'wsdl/security/algorithm_mapper'

module WSDL
  module Security
    class Verifier
      # Validates the cryptographic signature over the SignedInfo element.
      #
      # This validator performs the final cryptographic verification step:
      # 1. Canonicalizes the ds:SignedInfo element using the specified algorithm
      # 2. Decodes the ds:SignatureValue
      # 3. Verifies the signature using the certificate's public key
      #
      # This should be called after all reference digests have been verified,
      # as the SignedInfo contains the digest values being authenticated.
      #
      # @example Validating a signature
      #   validator = SignatureValidator.new(signature_node, certificate)
      #   if validator.valid?
      #     puts "Signature cryptographically valid"
      #   else
      #     puts validator.errors
      #   end
      #
      # @see https://www.w3.org/TR/xmldsig-core1/#sec-CoreValidation
      #
      class SignatureValidator < Base
        # Creates a new signature validator.
        #
        # @param signature_node [Nokogiri::XML::Element] the ds:Signature element
        # @param certificate [OpenSSL::X509::Certificate] the certificate for verification
        def initialize(signature_node, certificate)
          super()
          @signature_node = signature_node
          @certificate = certificate
        end

        # Validates the cryptographic signature.
        #
        # @return [Boolean] true if signature is cryptographically valid
        def valid?
          return add_failure('SignedInfo not found') unless signed_info_node
          return add_failure('SignatureValue not found') unless signature_value_node

          verify_signature
        end

        # Returns the signature algorithm URI.
        #
        # @return [String, nil] the algorithm URI
        def signature_algorithm
          signed_info_node&.at_xpath('ds:SignatureMethod/@Algorithm', ns)&.value
        end

        # Returns the canonicalization algorithm URI.
        #
        # @return [String, nil] the algorithm URI
        def canonicalization_algorithm
          signed_info_node&.at_xpath('ds:CanonicalizationMethod/@Algorithm', ns)&.value
        end

        private

        # Returns the ds:SignedInfo element.
        #
        # @return [Nokogiri::XML::Element, nil] the SignedInfo element
        def signed_info_node
          @signed_info_node ||= @signature_node&.at_xpath('ds:SignedInfo', ns)
        end

        # Returns the ds:SignatureValue element.
        #
        # @return [Nokogiri::XML::Element, nil] the SignatureValue element
        def signature_value_node
          @signature_value_node ||= @signature_node&.at_xpath('ds:SignatureValue', ns)
        end

        # Verifies the signature over the canonicalized SignedInfo.
        #
        # @return [Boolean] true if signature is valid
        def verify_signature
          canonical_signed_info = canonicalize_signed_info
          return false unless canonical_signed_info # Algorithm error already recorded

          signature_bytes = decode_signature_value

          verify_with_public_key(canonical_signed_info, signature_bytes)
        end

        # Canonicalizes the SignedInfo element.
        #
        # @return [String, nil] the canonicalized SignedInfo, or nil if algorithm unsupported
        def canonicalize_signed_info
          algorithm = AlgorithmMapper.c14n_algorithm(canonicalization_algorithm)
          canonicalizer = Canonicalizer.new(algorithm:)
          canonicalizer.canonicalize(signed_info_node)
        rescue UnsupportedAlgorithmError => e
          add_failure(e.message)
          nil
        end

        # Decodes the Base64-encoded SignatureValue.
        #
        # @return [String] the raw signature bytes
        def decode_signature_value
          Base64.decode64(signature_value_node.text)
        end

        # Verifies the signature using the certificate's public key.
        #
        # @param data [String] the canonicalized SignedInfo
        # @param signature [String] the raw signature bytes
        # @return [Boolean] true if verification succeeds
        def verify_with_public_key(data, signature)
          digest = build_digest_for_signature
          return false unless digest # Algorithm error already recorded

          public_key = @certificate.public_key

          return true if public_key.verify(digest, signature, data)

          add_failure('SignatureValue verification failed')
        rescue OpenSSL::PKey::PKeyError => e
          add_failure("Signature verification error: #{e.message}")
        end

        # Builds the OpenSSL::Digest for signature verification.
        #
        # @return [OpenSSL::Digest, nil] the digest instance, or nil if algorithm unsupported
        def build_digest_for_signature
          digest_name = AlgorithmMapper.signature_digest(signature_algorithm)
          OpenSSL::Digest.new(digest_name)
        rescue UnsupportedAlgorithmError => e
          add_failure(e.message)
          nil
        end
      end
    end
  end
end
