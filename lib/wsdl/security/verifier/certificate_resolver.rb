# frozen_string_literal: true

require 'openssl'
require 'base64'
require_relative 'base'

module WSDL
  module Security
    class Verifier
      # Resolves and normalizes X.509 certificates for signature verification.
      #
      # This class handles certificate extraction from SOAP messages and
      # normalization of certificate formats. It supports:
      #
      # - Extracting certificates from BinarySecurityToken elements
      # - Resolving certificates from KeyInfo/SecurityTokenReference
      #   (IssuerSerial and SubjectKeyIdentifier)
      # - Using externally provided certificates
      # - Normalizing PEM strings to OpenSSL::X509::Certificate objects
      #
      # @example Extracting certificate from document
      #   resolver = CertificateResolver.new(document, security_node)
      #   if resolver.resolve
      #     cert = resolver.certificate
      #   else
      #     puts resolver.errors
      #   end
      #
      # @example Using a provided certificate
      #   resolver = CertificateResolver.new(document, security_node, provided: pem_string)
      #   resolver.resolve
      #   cert = resolver.certificate
      #
      class CertificateResolver < Base
        # Maximum size in bytes for Base64-encoded BinarySecurityToken content.
        # X.509 certificates are typically 1-4 KB; 100 KB is extremely generous.
        MAX_ENCODED_TOKEN_SIZE = 100_000

        # Pattern for valid XML element IDs (NCName production).
        #
        # This is used before interpolating IDs into XPath expressions to
        # prevent XPath injection.
        #
        # @see https://www.w3.org/TR/xml-id/
        VALID_ID_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_.-]*\z/

        # @return [OpenSSL::X509::Certificate, nil] the resolved certificate
        attr_reader :certificate

        # Creates a new certificate resolver.
        #
        # @param document [Nokogiri::XML::Document] the SOAP document
        # @param security_node [Nokogiri::XML::Element, nil] the wsse:Security element
        # @param signature_node [Nokogiri::XML::Element, nil] the ds:Signature element
        # @param provided [OpenSSL::X509::Certificate, String, nil] optional certificate
        #   to use instead of extracting from the document
        # @param trust_store [OpenSSL::X509::Store, Symbol, String, Array, nil]
        #   trust material used to resolve external certificate references
        def initialize(document, security_node, signature_node: nil, provided: nil, trust_store: nil)
          super()
          @document = document
          @security_node = security_node
          @signature_node = signature_node
          @provided = provided
          @trust_store = trust_store
          @certificate = nil
        end

        # Resolves the certificate for verification.
        #
        # If a certificate was provided at initialization, it is normalized and used.
        # Otherwise, the certificate is resolved from the signature's
        # SecurityTokenReference.
        #
        # @return [Boolean] true if a certificate was successfully resolved
        def resolve
          @certificate = if @provided
            normalize_provided_certificate
          else
            extract_from_document
          end

          return true if @certificate

          add_failure('No certificate found for verification')
        end

        # Alias for consistency with other validators.
        #
        # @return [Boolean] true if certificate was resolved
        def valid?
          resolve
        end

        private

        # Normalizes a provided certificate to OpenSSL::X509::Certificate.
        #
        # @return [OpenSSL::X509::Certificate, nil] the normalized certificate
        def normalize_provided_certificate
          case @provided
          when OpenSSL::X509::Certificate
            @provided
          when String
            parse_certificate(@provided)
          else
            add_failure_nil("Invalid certificate type: #{@provided.class}")
          end
        end

        # Extracts the certificate from BinarySecurityToken in the document.
        #
        # @return [OpenSSL::X509::Certificate, nil] the extracted certificate
        def extract_from_document
          token_reference = find_security_token_reference
          return nil unless token_reference

          extract_from_security_token_reference(token_reference)
        end

        # Extracts certificate from wsse:SecurityTokenReference.
        #
        # Supported references:
        # - wsse:Reference -> wsse:BinarySecurityToken
        # - ds:X509IssuerSerial
        # - wsse:KeyIdentifier (X509SubjectKeyIdentifier)
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [OpenSSL::X509::Certificate, nil]
        def extract_from_security_token_reference(token_reference)
          extract_from_binary_security_token_reference(token_reference) ||
            extract_from_issuer_serial_reference(token_reference) ||
            extract_from_subject_key_identifier_reference(token_reference)
        end

        # Finds SecurityTokenReference from ds:Signature/ds:KeyInfo.
        #
        # @return [Nokogiri::XML::Element, nil]
        def find_security_token_reference
          signature_node = @signature_node || @document.at_xpath('//ds:Signature', ns)
          signature_node&.at_xpath('ds:KeyInfo/wsse:SecurityTokenReference', ns)
        end

        # Extracts certificate from wsse:Reference URI="#id".
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [OpenSSL::X509::Certificate, nil]
        def extract_from_binary_security_token_reference(token_reference)
          reference = token_reference.at_xpath('wsse:Reference', ns)
          return nil unless reference

          uri = reference['URI']&.strip
          return nil unless uri
          return add_failure_nil("Unsupported SecurityTokenReference URI: #{uri.inspect}") unless uri.start_with?('#')

          extract_from_binary_security_token(find_binary_security_token_by_id(uri.delete_prefix('#')))
        end

        # Extracts certificate by matching ds:X509IssuerSerial against trust-store
        # certificates.
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [OpenSSL::X509::Certificate, nil]
        def extract_from_issuer_serial_reference(token_reference)
          data = issuer_serial_reference_data(token_reference)
          return nil unless data

          parsed_issuer = parse_x509_name(data.fetch(:issuer_name))
          return nil unless parsed_issuer

          serial_number = parse_serial_number(data.fetch(:serial_text))
          return nil unless serial_number

          matches = trust_store_certificates.select { |candidate|
            issuer_serial_match?(candidate, parsed_issuer, serial_number)
          }

          select_unique_certificate(matches, 'X509IssuerSerial')
        end

        # Extracts certificate by matching wsse:KeyIdentifier (SKI) against
        # trust-store certificates.
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [OpenSSL::X509::Certificate, nil]
        def extract_from_subject_key_identifier_reference(token_reference)
          key_identifier = token_reference.at_xpath('wsse:KeyIdentifier', ns)
          return nil unless key_identifier
          return nil unless subject_key_identifier_reference?(key_identifier)

          encoded_ski = key_identifier.text.to_s.gsub(/\s+/, '')
          return nil if encoded_ski.empty?

          key_identifier_bytes = decode_base64(encoded_ski, 'SubjectKeyIdentifier')
          return nil unless key_identifier_bytes

          matches = trust_store_certificates.select { |candidate|
            subject_key_identifier_bytes(candidate) == key_identifier_bytes
          }

          select_unique_certificate(matches, 'X509SubjectKeyIdentifier')
        end

        # Extracts certificate from BinarySecurityToken element.
        #
        # @param bst [Nokogiri::XML::Element, nil]
        # @return [OpenSSL::X509::Certificate, nil]
        def extract_from_binary_security_token(bst)
          return nil unless bst

          encoded = bst.text.to_s.gsub(/\s+/, '')
          return add_failure_nil('BinarySecurityToken is empty') if encoded.empty?

          if encoded.bytesize > MAX_ENCODED_TOKEN_SIZE
            return add_failure_nil("BinarySecurityToken exceeds maximum size (#{encoded.bytesize} bytes)")
          end

          der_data = decode_base64(encoded, 'BinarySecurityToken')
          return nil unless der_data

          parse_certificate(der_data)
        end

        # Finds BinarySecurityToken by its ID attribute.
        #
        # Validates the ID format before interpolating into XPath to prevent
        # XPath injection, regardless of whether the caller performed validation.
        #
        # @param token_id [String]
        # @return [Nokogiri::XML::Element, nil]
        def find_binary_security_token_by_id(token_id)
          return nil unless @security_node
          unless valid_element_id?(token_id)
            return add_failure_nil("Invalid token reference ID format: #{token_id.inspect}")
          end

          @security_node.at_xpath("wsse:BinarySecurityToken[@wsu:Id='#{token_id}']", ns) ||
            @security_node.at_xpath("wsse:BinarySecurityToken[@Id='#{token_id}']", ns) ||
            @security_node.at_xpath("wsse:BinarySecurityToken[@xml:id='#{token_id}']")
        end

        # Parses certificate data into an OpenSSL::X509::Certificate.
        #
        # @param data [String] PEM or DER encoded certificate data
        # @return [OpenSSL::X509::Certificate, nil] the parsed certificate
        def parse_certificate(data)
          OpenSSL::X509::Certificate.new(data)
        rescue OpenSSL::X509::CertificateError => e
          add_failure_nil("Failed to parse certificate: #{e.message}")
        end

        # Returns trust-store certificates usable for identifier-based lookup.
        #
        # Only array trust-stores are enumerable and therefore suitable for
        # IssuerSerial/SKI resolution.
        #
        # @return [Array<OpenSSL::X509::Certificate>]
        def trust_store_certificates
          return [] unless @trust_store.is_a?(Array)

          @trust_store_certificates ||= @trust_store.filter_map { |entry|
            case entry
            when OpenSSL::X509::Certificate
              entry
            when String
              parse_certificate_without_error(entry)
            end
          }
        end

        # Parses certificate without recording failures.
        #
        # Trust-store entries may contain non-certificate values; those are
        # ignored for lookup and handled by chain validation separately.
        #
        # @param data [String]
        # @return [OpenSSL::X509::Certificate, nil]
        def parse_certificate_without_error(data)
          OpenSSL::X509::Certificate.new(data)
        rescue OpenSSL::X509::CertificateError
          nil
        end

        # Returns true if the certificate matches issuer and serial.
        #
        # @param certificate [OpenSSL::X509::Certificate]
        # @param issuer_name [OpenSSL::X509::Name]
        # @param serial_number [Integer]
        # @return [Boolean]
        def issuer_serial_match?(certificate, issuer_name, serial_number)
          return false unless certificate.serial == serial_number

          candidate_issuer = parse_x509_name(certificate.issuer.to_s(OpenSSL::X509::Name::RFC2253), add_error: false)
          return false unless candidate_issuer

          candidate_issuer.to_a == issuer_name.to_a
        end

        # Parses an X.509 distinguished name string.
        #
        # @param name [String]
        # @param add_error [Boolean]
        # @return [OpenSSL::X509::Name, nil]
        def parse_x509_name(name, add_error: true)
          OpenSSL::X509::Name.parse(name)
        rescue OpenSSL::X509::NameError => e
          return nil unless add_error

          add_failure_nil("Invalid X509IssuerName value: #{e.message}")
        end

        # Parses X509SerialNumber string as base-10 integer.
        #
        # @param value [String]
        # @return [Integer, nil]
        def parse_serial_number(value)
          serial = Integer(value, 10)
          return serial unless serial.negative?

          add_failure_nil("Invalid X509SerialNumber value: #{value.inspect}")
        rescue ArgumentError
          add_failure_nil("Invalid X509SerialNumber value: #{value.inspect}")
        end

        # Returns true if KeyIdentifier is an X.509 Subject Key Identifier.
        #
        # @param key_identifier [Nokogiri::XML::Element]
        # @return [Boolean]
        def subject_key_identifier_reference?(key_identifier)
          value_type = key_identifier['ValueType']&.strip
          return false if value_type.nil? || value_type.empty?

          value_type == Constants::TokenProfiles::X509::SKI || value_type.end_with?('#X509SubjectKeyIdentifier')
        end

        # Returns Subject Key Identifier bytes for a certificate.
        #
        # @param certificate [OpenSSL::X509::Certificate]
        # @return [String, nil]
        def subject_key_identifier_bytes(certificate)
          extension = certificate.extensions.find { |ext| ext.oid == 'subjectKeyIdentifier' }
          return nil unless extension

          hex = extension.value.scan(/[0-9a-fA-F]{2}/).join
          return nil if hex.empty?

          [hex].pack('H*')
        end

        # Decodes base64 data with strict validation.
        #
        # @param data [String]
        # @param label [String]
        # @return [String, nil]
        def decode_base64(data, label)
          Base64.strict_decode64(data)
        rescue ArgumentError => e
          add_failure_nil("Invalid #{label} value: #{e.message}")
        end

        # Returns the matched certificate when exactly one candidate matches.
        #
        # @param candidates [Array<OpenSSL::X509::Certificate>]
        # @param reference_type [String]
        # @return [OpenSSL::X509::Certificate, nil]
        def select_unique_certificate(candidates, reference_type)
          return nil if candidates.empty?
          return candidates.first if candidates.one?

          add_failure_nil("Multiple certificates matched #{reference_type}")
        end

        # Extracts issuer and serial values from X509IssuerSerial reference.
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [Hash{Symbol => String}, nil]
        def issuer_serial_reference_data(token_reference)
          issuer_serial = issuer_serial_node(token_reference)
          return nil unless issuer_serial

          issuer_name = issuer_name_text(issuer_serial)
          serial_text = serial_number_text(issuer_serial)
          return nil unless present_value?(issuer_name) && present_value?(serial_text)

          { issuer_name:, serial_text: }
        end

        # Returns ds:X509IssuerSerial node from a SecurityTokenReference.
        #
        # @param token_reference [Nokogiri::XML::Element]
        # @return [Nokogiri::XML::Element, nil]
        def issuer_serial_node(token_reference)
          token_reference.at_xpath('ds:X509Data/ds:X509IssuerSerial', ns)
        end

        # Returns text value of ds:X509IssuerName.
        #
        # @param issuer_serial [Nokogiri::XML::Element]
        # @return [String, nil]
        def issuer_name_text(issuer_serial)
          issuer_serial.at_xpath('ds:X509IssuerName', ns)&.text&.strip
        end

        # Returns text value of ds:X509SerialNumber.
        #
        # @param issuer_serial [Nokogiri::XML::Element]
        # @return [String, nil]
        def serial_number_text(issuer_serial)
          issuer_serial.at_xpath('ds:X509SerialNumber', ns)&.text&.strip
        end

        # Returns true when a value is non-nil and not empty.
        #
        # @param value [String, nil]
        # @return [Boolean]
        def present_value?(value)
          !value.nil? && !value.empty?
        end

        # Validates whether an element ID is safe for XPath interpolation.
        #
        # @param element_id [String]
        # @return [Boolean]
        def valid_element_id?(element_id)
          !element_id.empty? && element_id.match?(VALID_ID_PATTERN)
        end
      end
    end
  end
end
