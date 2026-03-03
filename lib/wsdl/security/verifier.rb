# frozen_string_literal: true

require 'wsdl/xml/parser'
require 'wsdl/security/verifier/base'
require 'wsdl/security/verifier/structure_validator'
require 'wsdl/security/verifier/certificate_resolver'
require 'wsdl/security/verifier/certificate_validator'
require 'wsdl/security/verifier/reference_validator'
require 'wsdl/security/verifier/signature_validator'
require 'wsdl/security/verifier/timestamp_validator'

module WSDL
  module Security
    # Verifies XML Digital Signatures and timestamps in SOAP responses.
    #
    # This class coordinates multiple validation steps to provide comprehensive
    # security verification including:
    #
    # - *Structural Validation* — Detects XML Signature Wrapping (XSW) attacks
    # - *Certificate Resolution* — Extracts or validates signing certificates
    # - *Certificate Validation* — Checks validity period and trust chain
    # - *Reference Verification* — Validates digests of signed elements
    # - *Signature Verification* — Cryptographic validation of SignatureValue
    # - *Timestamp Validation* — Freshness checks to prevent replay attacks
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
    # @example With certificate chain validation
    #   verifier = Verifier.new(response_xml, trust_store: :system)
    #   verifier.valid?
    #
    # @example With custom CA certificates
    #   verifier = Verifier.new(response_xml, trust_store: [ca_cert])
    #   verifier.valid?
    #
    # @example With timestamp validation (enabled by default)
    #   verifier = Verifier.new(response_xml, clock_skew: 600)
    #   verifier.valid?  # checks signature AND timestamp
    #
    # @example Disable timestamp validation
    #   verifier = Verifier.new(response_xml, validate_timestamp: false)
    #   verifier.valid?  # checks signature only
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    # @see https://www.w3.org/TR/xmldsig-bestpractices/
    # @see https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-SOAPMessageSecurity-v1.1.1-os.html
    #
    class Verifier
      # Local aliases for namespace constants
      SecurityNS = Constants::NS::Security

      # Alias for XML Signature namespace constants.
      #
      # @return [Module]
      SignatureNS = Constants::NS::Signature

      # @return [Array<String>] errors encountered during verification
      attr_reader :errors

      # @return [OpenSSL::X509::Certificate, nil] certificate used for verification
      attr_reader :certificate

      # Creates a new Verifier instance.
      #
      # @param xml [String, Nokogiri::XML::Document] the SOAP response XML
      # @param certificate [OpenSSL::X509::Certificate, String, nil] optional certificate
      #   to use for verification instead of extracting from the message
      # @param trust_store [OpenSSL::X509::Store, Symbol, String, Array, nil] trust store
      #   for certificate chain validation:
      #   - `:system` — Use system default CA certificates
      #   - `String` — Path to CA bundle file or directory
      #   - `Array<OpenSSL::X509::Certificate>` — Array of trusted CA certificates
      #   - `OpenSSL::X509::Store` — Pre-configured certificate store
      #   - `nil` — Skip chain validation (default)
      # @param check_validity [Boolean] whether to check the certificate's validity
      #   period (not_before and not_after). Default: true
      # @param validate_timestamp [Boolean] whether to validate timestamp freshness.
      #   Default: true. Per WS-Security spec, timestamps are optional, so this only
      #   validates when a timestamp is present.
      # @param clock_skew [Integer] acceptable clock skew in seconds for timestamp
      #   validation. Default: 300 (5 minutes). Per WS-I BSP guidance.
      # rubocop:disable Metrics/ParameterLists
      def initialize(xml, certificate: nil, trust_store: nil, check_validity: true,
                     validate_timestamp: true, clock_skew: 300)
        # rubocop:enable Metrics/ParameterLists
        @document = parse_document(xml)
        @provided_certificate = certificate
        @trust_store = trust_store
        @check_validity = check_validity
        @validate_timestamp = validate_timestamp
        @clock_skew = clock_skew
        @errors = []
        @verified = nil
        @certificate = normalize_certificate(certificate) if certificate
      end

      # Returns whether the signature (and timestamp, if enabled) is valid.
      #
      # Performs full verification including:
      # 1. Structural validation (XSW protection)
      # 2. Certificate resolution
      # 3. Certificate validation (validity period and chain)
      # 4. Reference digest verification
      # 5. Cryptographic signature verification
      # 6. Timestamp freshness validation (if enabled and timestamp present)
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

      # Returns whether a timestamp is present in the document.
      #
      # @return [Boolean] true if wsu:Timestamp exists in the Security header
      def timestamp_present?
        timestamp_validator.timestamp_present?
      end

      # Returns whether the timestamp is valid (fresh).
      #
      # Returns true if:
      # - No timestamp is present (timestamps are optional per spec)
      # - Timestamp is present and within acceptable time bounds
      #
      # @return [Boolean] true if timestamp is valid or not present
      def timestamp_valid?
        timestamp_validator.valid?
      end

      # Returns the parsed timestamp information.
      #
      # @return [Hash, nil] hash with :created_at and :expires_at keys,
      #   or nil if no timestamp present
      def timestamp
        timestamp_validator.timestamp
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

        # Phase 3: Certificate validation (validity + chain)
        return false unless run_certificate_validation

        # Phase 4: Reference validation (digests and element positions)
        return false unless run_reference_validation

        # Phase 5: Cryptographic signature verification
        return false unless run_signature_validation

        # Phase 6: Timestamp validation (after signature, so signed timestamp is verified)
        run_timestamp_validation
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
      # Phase 3: Certificate Validation
      # ============================================================

      def run_certificate_validation
        validator = Verifier::CertificateValidator.new(
          @certificate,
          trust_store: @trust_store,
          check_validity: @check_validity
        )

        return true if validator.valid?

        aggregate_errors(validator)
        false
      end

      # ============================================================
      # Phase 4: Reference Validation
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
      # Phase 5: Signature Validation
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
      # Phase 6: Timestamp Validation
      # ============================================================

      def run_timestamp_validation # rubocop:disable Naming/PredicateMethod
        return true unless @validate_timestamp

        validator = timestamp_validator
        return true if validator.valid?

        aggregate_errors(validator)
        false
      end

      def timestamp_validator
        @timestamp_validator ||= Verifier::TimestampValidator.new(
          @document,
          clock_skew: @clock_skew
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
          'ds' => SignatureNS::DS,
          'wsse' => SecurityNS::WSSE,
          'wsu' => SecurityNS::WSU
        }
      end

      def aggregate_errors(validator)
        @errors.concat(validator.errors)
      end
    end
  end
end
