# frozen_string_literal: true

require 'wsdl/xml/parser'
require 'wsdl/security/verifier/base'
require 'wsdl/security/verifier/structure_validator'
require 'wsdl/security/verifier/certificate_resolver'
require 'wsdl/security/verifier/reference_validator'
require 'wsdl/security/verifier/signature_validator'

module WSDL
  module Security
    # Verifies XML Digital Signatures in SOAP responses.
    #
    # This class coordinates multiple validation steps to provide comprehensive
    # signature verification including:
    #
    # - *Structural Validation* — Detects XML Signature Wrapping (XSW) attacks
    # - *Certificate Resolution* — Extracts or validates signing certificates
    # - *Reference Verification* — Validates digests of signed elements
    # - *Signature Verification* — Cryptographic validation of SignatureValue
    #
    # The verification process follows W3C XML Signature Best Practices,
    # running structural checks before expensive cryptographic operations.
    #
    # @example Basic verification
    #   verifier = Verifier.new(response_xml)
    #   if verifier.valid?
    #     puts "Signature is valid!"
    #     puts "Signed elements: #{verifier.signed_elements}"
    #   else
    #     puts "Signature invalid: #{verifier.errors}"
    #   end
    #
    # @example With a provided certificate
    #   verifier = Verifier.new(response_xml, certificate: server_cert)
    #   verifier.valid?
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    # @see https://www.w3.org/TR/xmldsig-bestpractices/
    # @see https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-SOAPMessageSecurity-v1.1.1-os.html
    #
    class Verifier
      include Constants

      # @return [Array<String>] errors encountered during verification
      attr_reader :errors

      # @return [OpenSSL::X509::Certificate, nil] certificate used for verification
      attr_reader :certificate

      # Creates a new Verifier instance.
      #
      # @param xml [String, Nokogiri::XML::Document] the SOAP response XML
      # @param certificate [OpenSSL::X509::Certificate, String, nil] optional certificate
      #   to use for verification instead of extracting from the message
      def initialize(xml, certificate: nil)
        @document = parse_document(xml)
        @provided_certificate = certificate
        @errors = []
        @verified = nil
        @certificate = normalize_certificate(certificate) if certificate
      end

      # Returns whether the signature is valid.
      #
      # Performs full verification including:
      # 1. Structural validation (XSW protection)
      # 2. Certificate resolution
      # 3. Reference digest verification
      # 4. Cryptographic signature verification
      #
      # @return [Boolean] true if signature is present and valid
      def valid?
        return @verified unless @verified.nil?

        @verified = perform_verification
      end

      # Returns whether a signature is present in the document.
      #
      # @return [Boolean] true if a ds:Signature element exists
      def signature_present?
        structure_validator.signature_present?
      end

      # Returns the IDs of all signed elements.
      #
      # @return [Array<String>] element IDs (without # prefix)
      def signed_element_ids
        return [] unless signature_present?

        reference_validator.referenced_ids
      end

      # Returns the names of all signed elements.
      #
      # @return [Array<String>] element names (e.g., ['Body', 'Timestamp'])
      def signed_elements
        signed_element_ids.filter_map { |id| safe_find_element_by_id(id)&.name }
      end

      # Returns the signature algorithm URI.
      #
      # @return [String, nil] the algorithm URI (e.g., 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
      def signature_algorithm
        signature_validator&.signature_algorithm
      end

      # Returns the digest algorithm URI from the first reference.
      #
      # @return [String, nil] the algorithm URI (e.g., 'http://www.w3.org/2001/04/xmlenc#sha256')
      def digest_algorithm
        signed_info_node&.at_xpath('ds:Reference/ds:DigestMethod/@Algorithm', ns)&.value
      end

      private

      # ============================================================
      # Document Parsing
      # ============================================================

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

      # ============================================================
      # Main Verification Flow
      # ============================================================

      def perform_verification
        @errors = []

        # Phase 1: Structural validation (fast, before expensive crypto)
        return false unless run_structure_validation

        # Phase 2: Certificate resolution
        return false unless run_certificate_resolution

        # Phase 3: Reference validation (digests and element positions)
        return false unless run_reference_validation

        # Phase 4: Cryptographic signature verification
        run_signature_validation
      end

      # ============================================================
      # Phase 1: Structure Validation
      # ============================================================

      def run_structure_validation
        validator = structure_validator
        return true if validator.valid?

        aggregate_errors(validator)
        false
      end

      def structure_validator
        @structure_validator ||= Verifier::StructureValidator.new(@document)
      end

      # ============================================================
      # Phase 2: Certificate Resolution
      # ============================================================

      def run_certificate_resolution
        resolver = Verifier::CertificateResolver.new(
          @document,
          structure_validator.security_node,
          provided: @provided_certificate
        )

        unless resolver.resolve
          aggregate_errors(resolver)
          return false
        end

        @certificate = resolver.certificate
        true
      end

      # ============================================================
      # Phase 3: Reference Validation
      # ============================================================

      def run_reference_validation
        validator = reference_validator
        return true if validator.valid?

        aggregate_errors(validator)
        false
      end

      def reference_validator
        @reference_validator ||= Verifier::ReferenceValidator.new(@document, signed_info_node)
      end

      # ============================================================
      # Phase 4: Signature Validation
      # ============================================================

      def run_signature_validation
        validator = signature_validator
        return true if validator.valid?

        aggregate_errors(validator)
        false
      end

      def signature_validator
        @signature_validator ||= Verifier::SignatureValidator.new(
          structure_validator.signature_node,
          @certificate
        )
      end

      # ============================================================
      # Node Accessors
      # ============================================================

      def signed_info_node
        structure_validator.signature_node&.at_xpath('ds:SignedInfo', ns)
      end

      # Safely finds an element by ID with validation.
      # Returns nil and records error for invalid IDs.
      #
      # @param id [String] the element ID
      # @return [Nokogiri::XML::Element, nil] the element or nil
      def safe_find_element_by_id(id)
        return nil unless valid_element_id?(id)

        find_element_by_id(id)
      end

      def find_element_by_id(id)
        @document.at_xpath("//*[@wsu:Id='#{id}']", ns) ||
          @document.at_xpath("//*[@Id='#{id}']") ||
          @document.at_xpath("//*[@xml:id='#{id}']")
      end

      # Validates element ID format to prevent XPath injection.
      #
      # @param id [String, nil] the ID to validate
      # @return [Boolean] true if valid
      def valid_element_id?(id)
        return add_error('Reference URI is empty') if id.nil? || id.empty?
        return true if id.match?(Verifier::ReferenceValidator::VALID_ID_PATTERN)

        add_error("Invalid element ID format (possible XPath injection): #{id.inspect}")
      end

      def add_error(message)
        @errors << message
        false
      end

      # ============================================================
      # Helpers
      # ============================================================

      def ns
        {
          'ds' => NS_DS,
          'wsse' => NS_WSSE,
          'wsu' => NS_WSU
        }
      end

      def aggregate_errors(validator)
        @errors.concat(validator.errors)
      end
    end
  end
end
