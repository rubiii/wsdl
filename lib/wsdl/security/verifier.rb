# frozen_string_literal: true

require 'openssl'
require 'base64'
require 'wsdl/xml/parser'
require 'wsdl/security/secure_compare'

module WSDL
  module Security
    # Verifies XML Digital Signatures in SOAP responses.
    #
    # This provides assurance that:
    # - The response hasn't been tampered with (integrity)
    # - The response came from someone with the private key (authenticity)
    #
    # @example Basic verification
    #   verifier = Verifier.new(response_xml)
    #   if verifier.valid?
    #     puts "Signature is valid!"
    #     puts "Signed elements: #{verifier.signed_element_ids}"
    #   else
    #     puts "Signature invalid: #{verifier.errors}"
    #   end
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    #
    class Verifier
      include Constants

      # Pattern for valid XML element IDs (NCName production).
      # This prevents XPath injection by rejecting IDs containing quotes,
      # brackets, operators, or other characters that could alter XPath semantics.
      #
      # Allowed characters (explicit allowlist):
      #   - First character: ASCII letter (a-z, A-Z) or underscore
      #   - Subsequent: ASCII letters, digits, underscores, hyphens, periods
      #
      # Explicitly disallowed (non-exhaustive):
      #   - Single/double quotes (' ")
      #   - Brackets ([ ] ( ) { })
      #   - XPath operators (| / @ = < >)
      #   - Whitespace
      #   - Null bytes and control characters
      #
      # @see https://www.w3.org/TR/xml-id/
      VALID_ID_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_.-]*\z/

      # @return [Array<String>] errors encountered during verification
      attr_reader :errors

      # @return [OpenSSL::X509::Certificate, nil] certificate used for verification
      attr_reader :certificate

      # @param xml [String, Nokogiri::XML::Document] the SOAP response XML
      # @param certificate [OpenSSL::X509::Certificate, String, nil] optional certificate
      def initialize(xml, certificate: nil)
        @document = parse_document(xml)
        @certificate = normalize_certificate(certificate) if certificate
        @errors = []
        @verified = nil
      end

      # Returns whether the signature is valid.
      # @return [Boolean]
      def valid?
        return @verified unless @verified.nil?

        @verified = perform_verification
      end

      # @return [Boolean] whether a signature is present
      def signature_present?
        !signature_node.nil?
      end

      # @return [Array<String>] IDs of signed elements (without # prefix)
      def signed_element_ids
        return [] unless signature_present?

        references.filter_map { |ref| extract_reference_id(ref) }
      end

      # @return [Array<String>] element names (e.g., ['Body', 'Timestamp'])
      def signed_elements
        signed_element_ids.filter_map { |id| find_element_by_id(id)&.name }
      end

      # @return [String, nil] the signature algorithm URI
      def signature_algorithm
        signed_info_node&.at_xpath('ds:SignatureMethod/@Algorithm', ns)&.value
      end

      # @return [String, nil] the digest algorithm URI from the first reference
      def digest_algorithm
        references.first&.at_xpath('ds:DigestMethod/@Algorithm', ns)&.value
      end

      private

      def parse_document(xml)
        case xml
        when Nokogiri::XML::Document then xml
        when String then XML::Parser.parse(xml, noblanks: true)
        else raise ArgumentError, "Expected String or Nokogiri::XML::Document, got #{xml.class}"
        end
      end

      def normalize_certificate(cert)
        return cert if cert.is_a?(OpenSSL::X509::Certificate)
        return OpenSSL::X509::Certificate.new(cert) if cert.is_a?(String)

        raise ArgumentError, "Invalid certificate type: #{cert.class}"
      end

      def perform_verification
        @errors = []
        return add_failure('No signature found in document') unless signature_present?
        return add_failure('No certificate found for verification') unless load_certificate
        return false unless verify_all_references

        verify_signature_value
      end

      def load_certificate
        return true if @certificate

        bst = security_node&.at_xpath('wsse:BinarySecurityToken', ns)
        return false unless bst

        @certificate = OpenSSL::X509::Certificate.new(Base64.decode64(bst.text))
        true
      rescue OpenSSL::X509::CertificateError => e
        add_failure("Failed to parse BinarySecurityToken: #{e.message}")
      end

      def verify_all_references
        references.all? { |ref| verify_single_reference(ref) }
      end

      def verify_single_reference(ref)
        ref_data = extract_reference_data(ref)
        return false unless ref_data

        element = find_element_by_id(ref_data[:id])
        return add_failure("Referenced element not found: #{ref_data[:uri]}") unless element

        computed = compute_digest(element, ref_data[:c14n_alg], ref_data[:digest_alg])
        return true if SecureCompare.equal?(computed, ref_data[:expected])

        add_failure("Digest mismatch for #{ref_data[:uri]}")
      end

      def extract_reference_data(ref)
        uri = ref['URI']
        return add_failure_nil('Reference missing URI attribute') unless uri

        expected = ref.at_xpath('ds:DigestValue', ns)&.text
        return add_failure_nil("Reference missing DigestValue: #{uri}") unless expected

        digest_alg = ref.at_xpath('ds:DigestMethod/@Algorithm', ns)&.value
        return add_failure_nil("Reference missing DigestMethod: #{uri}") unless digest_alg

        build_reference_hash(ref, uri, expected, digest_alg)
      end

      def build_reference_hash(ref, uri, expected, digest_alg)
        {
          uri: uri,
          id: uri.delete_prefix('#'),
          expected: expected,
          digest_alg: digest_alg,
          c14n_alg: ref.at_xpath('ds:Transforms/ds:Transform/@Algorithm', ns)&.value || EXC_C14N_URI
        }
      end

      def compute_digest(element, c14n_alg, digest_alg)
        canonicalizer = Canonicalizer.new(algorithm: AlgorithmMapper.c14n_algorithm(c14n_alg))
        digester = Digester.new(algorithm: AlgorithmMapper.digest_algorithm(digest_alg))
        digester.base64_digest(canonicalizer.canonicalize(element))
      end

      def verify_signature_value
        sig_value_node = signature_node.at_xpath('ds:SignatureValue', ns)
        return add_failure('SignatureValue not found') unless sig_value_node

        canonical = canonicalize_signed_info
        verify_with_certificate(sig_value_node, canonical)
      end

      def canonicalize_signed_info
        c14n_alg = signed_info_node.at_xpath('ds:CanonicalizationMethod/@Algorithm', ns)&.value
        canonicalizer = Canonicalizer.new(algorithm: AlgorithmMapper.c14n_algorithm(c14n_alg))
        canonicalizer.canonicalize(signed_info_node)
      end

      def verify_with_certificate(sig_value_node, canonical)
        digest = OpenSSL::Digest.new(AlgorithmMapper.signature_digest(signature_algorithm))
        signature = Base64.decode64(sig_value_node.text)

        return true if @certificate.public_key.verify(digest, signature, canonical)

        add_failure('SignatureValue verification failed')
      rescue OpenSSL::PKey::PKeyError => e
        add_failure("Signature verification error: #{e.message}")
      end

      def extract_reference_id(ref)
        uri = ref['URI']
        uri&.delete_prefix('#')
      end

      def find_element_by_id(id)
        return nil unless valid_element_id?(id)

        @document.at_xpath("//*[@wsu:Id='#{id}']", ns) ||
          @document.at_xpath("//*[@Id='#{id}']") ||
          @document.at_xpath("//*[@xml:id='#{id}']")
      end

      # Validates that an element ID is safe to use in XPath queries.
      #
      # This prevents XPath injection attacks by ensuring IDs contain only
      # characters allowed in XML NCName (letters, digits, hyphens, underscores, periods).
      #
      # @param id [String, nil] the element ID to validate
      # @return [Boolean] true if the ID is valid and safe to use
      # @see VALID_ID_PATTERN
      def valid_element_id?(id)
        return add_failure('Reference URI is empty') if id.nil? || id.empty?
        return true if id.match?(VALID_ID_PATTERN)

        add_failure("Invalid element ID format (possible XPath injection): #{id.inspect}")
      end

      def signature_node
        @signature_node ||= @document.at_xpath('//ds:Signature', ns)
      end

      def signed_info_node
        @signed_info_node ||= signature_node&.at_xpath('ds:SignedInfo', ns)
      end

      def security_node
        @security_node ||= @document.at_xpath('//wsse:Security', ns)
      end

      def references
        @references ||= signed_info_node&.xpath('ds:Reference', ns) || []
      end

      def ns
        { 'ds' => NS_DS, 'wsse' => NS_WSSE, 'wsu' => NS_WSU }
      end

      def add_failure(message)
        @errors << message
        false
      end

      def add_failure_nil(message)
        @errors << message
        nil
      end
    end
  end
end
