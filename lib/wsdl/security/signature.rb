# frozen_string_literal: true

require 'openssl'
require 'base64'

class WSDL
  module Security
    # Handles XML Digital Signature (XML-DSig) creation for WS-Security.
    #
    # The Signature class orchestrates the signing process for SOAP messages:
    # 1. Digests referenced elements (Timestamp, Body, etc.)
    # 2. Builds the SignedInfo element with References
    # 3. Canonicalizes and signs the SignedInfo
    # 4. Builds the complete Signature element with KeyInfo
    #
    # @example Basic usage
    #   signature = Signature.new(
    #     certificate: OpenSSL::X509::Certificate.new(cert_pem),
    #     private_key: OpenSSL::PKey::RSA.new(key_pem, 'password')
    #   )
    #   signature.sign_element(body_node, id: 'Body-123')
    #   signature.sign_element(timestamp_node, id: 'Timestamp-456')
    #   signature.apply(document)
    #
    # @example With IssuerSerial key reference
    #   signature = Signature.new(
    #     certificate: cert,
    #     private_key: key,
    #     key_reference: :issuer_serial
    #   )
    #
    # @example With explicit namespace prefixes
    #   signature = Signature.new(
    #     certificate: cert,
    #     private_key: key,
    #     explicit_namespace_prefixes: true
    #   )
    #
    # @see https://www.w3.org/TR/xmldsig-core1/
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf
    #
    class Signature
      include Constants

      # Signature algorithm configurations
      SIGNATURE_ALGORITHMS = {
        sha1: {
          id: RSA_SHA1_URI,
          digest: 'SHA1'
        },
        sha256: {
          id: RSA_SHA256_URI,
          digest: 'SHA256'
        },
        sha512: {
          id: RSA_SHA512_URI,
          digest: 'SHA512'
        }
      }.freeze

      # Default digest algorithm
      DEFAULT_ALGORITHM = :sha256

      # Default key reference method
      DEFAULT_KEY_REFERENCE = KeyReference::BINARY_SECURITY_TOKEN

      # Returns the X.509 certificate.
      # @return [OpenSSL::X509::Certificate]
      attr_reader :certificate

      # Returns the private key.
      # @return [OpenSSL::PKey::RSA, OpenSSL::PKey::EC]
      attr_reader :private_key

      # Returns the digest algorithm symbol.
      # @return [Symbol]
      attr_reader :digest_algorithm

      # Returns the unique ID for the BinarySecurityToken.
      # @return [String]
      attr_reader :security_token_id

      # Returns the references to be signed.
      # @return [Array<Reference>]
      attr_reader :references

      # Returns the key reference method.
      # @return [Symbol]
      attr_reader :key_reference

      # Returns whether explicit namespace prefixes are enabled.
      # @return [Boolean]
      attr_reader :explicit_namespace_prefixes

      # Creates a new Signature instance.
      #
      # @param certificate [OpenSSL::X509::Certificate] the X.509 certificate
      # @param private_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC] the private key
      # @param digest_algorithm [Symbol] the digest algorithm (:sha1, :sha256, :sha512)
      # @param security_token_id [String, nil] the wsu:Id for BinarySecurityToken
      # @param key_reference [Symbol] how to reference the certificate:
      #   - :binary_security_token (default) - embed certificate in message
      #   - :issuer_serial - reference by issuer DN and serial number
      #   - :subject_key_identifier - reference by SKI extension
      # @param explicit_namespace_prefixes [Boolean] whether to use explicit ns prefixes
      #
      # @raise [ArgumentError] if certificate or private key is missing
      #
      def initialize(certificate:, private_key:, digest_algorithm: DEFAULT_ALGORITHM,
                     security_token_id: nil, key_reference: DEFAULT_KEY_REFERENCE,
                     explicit_namespace_prefixes: false)
        @certificate = certificate or raise ArgumentError, 'certificate is required'
        @private_key = private_key or raise ArgumentError, 'private_key is required'
        @digest_algorithm = digest_algorithm
        @security_token_id = security_token_id || IdGenerator.for('SecurityToken')
        @key_reference = key_reference
        @explicit_namespace_prefixes = explicit_namespace_prefixes
        @references = []

        @canonicalizer = Canonicalizer.new(algorithm: :exclusive_1_0)
        @digester = Digester.new(algorithm: digest_algorithm)
        @xml_helper = XmlBuilderHelper.new(explicit_prefixes: explicit_namespace_prefixes)
        @signature_algorithm = SIGNATURE_ALGORITHMS[digest_algorithm] or
          raise ArgumentError, "Unknown digest algorithm: #{digest_algorithm.inspect}"
      end

      # Adds an element to the list of elements to be signed.
      #
      # The element must have a wsu:Id attribute that will be used as the
      # Reference URI. If the element doesn't have an ID, you must provide one.
      #
      # @param node [Nokogiri::XML::Node] the element to sign
      # @param id [String, nil] the wsu:Id value (extracted from node if nil)
      # @param inclusive_namespaces [Array<String>, nil] namespace prefixes for C14N
      #
      # @return [self] for method chaining
      #
      # @raise [ArgumentError] if no ID can be determined
      #
      def sign_element(node, id: nil, inclusive_namespaces: nil)
        element_id = id || extract_id(node)
        raise ArgumentError, 'Element must have a wsu:Id attribute or id must be provided' unless element_id

        # Canonicalize and compute digest
        canonical_xml = @canonicalizer.canonicalize(node, inclusive_namespaces: inclusive_namespaces)
        digest_value = @digester.base64_digest(canonical_xml)

        @references << Reference.new(
          id: element_id,
          digest_value: digest_value,
          inclusive_namespaces: inclusive_namespaces
        )

        self
      end

      # Computes digest for an element and stores the reference.
      #
      # This is an alias for {#sign_element} with a more descriptive name
      # for the initial digest phase.
      #
      # @param (see #sign_element)
      # @return (see #sign_element)
      #
      alias digest! sign_element

      # Applies the signature to the document.
      #
      # This method builds the complete Signature element including:
      # - BinarySecurityToken (X.509 certificate) - if using :binary_security_token
      # - SignedInfo with References
      # - SignatureValue
      # - KeyInfo with appropriate reference type
      #
      # @param document [Nokogiri::XML::Document] the SOAP document
      # @param security_node [Nokogiri::XML::Node] the wsse:Security element
      #
      # @return [Nokogiri::XML::Document] the signed document
      #
      def apply(document, security_node)
        # Build SignedInfo
        signed_info_xml = build_signed_info

        # Canonicalize SignedInfo and compute signature
        canonical_signed_info = @canonicalizer.canonicalize(signed_info_xml)
        signature_value = compute_signature(canonical_signed_info)

        # Build and insert complete Signature element
        build_signature_element(document, security_node, signed_info_xml, signature_value)

        document
      end

      # Returns the Base64-encoded DER representation of the certificate.
      #
      # This is used in the BinarySecurityToken element.
      #
      # @return [String] the Base64-encoded certificate
      #
      def encoded_certificate
        Base64.strict_encode64(@certificate.to_der)
      end

      # Returns whether any references have been added.
      #
      # @return [Boolean] true if there are references to sign
      #
      def references?
        !@references.empty?
      end

      # Returns whether explicit namespace prefixes should be used.
      #
      # @return [Boolean]
      #
      def explicit_namespace_prefixes?
        @explicit_namespace_prefixes == true
      end

      # Clears all references to allow reuse.
      #
      # @return [self]
      #
      def clear_references
        @references = []
        self
      end

      private

      # Extracts the wsu:Id attribute from a node.
      #
      # @param node [Nokogiri::XML::Node] the node to extract ID from
      # @return [String, nil] the ID value or nil
      #
      def extract_id(node)
        # Try wsu:Id first (most common in WS-Security)
        id = node.attribute_with_ns('Id', NS_WSU)&.value
        return id if id

        # Fall back to plain Id attribute
        node['Id']
      end

      # Builds the SignedInfo element.
      #
      # @return [Nokogiri::XML::Node] the SignedInfo element
      #
      def build_signed_info
        builder = Nokogiri::XML::Builder.new do |xml|
          @xml_helper.build_element(xml, :ds, 'SignedInfo') do
            @xml_helper.build_child(xml, :ds, 'CanonicalizationMethod',
                                    Algorithm: @canonicalizer.algorithm_id)
            @xml_helper.build_child(xml, :ds, 'SignatureMethod',
                                    Algorithm: @signature_algorithm[:id])

            @references.each do |reference|
              build_reference(xml, reference)
            end
          end
        end

        builder.doc.root
      end

      # Builds a Reference element within SignedInfo.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @param reference [Reference] the reference data
      #
      def build_reference(xml, reference)
        @xml_helper.build_child(xml, :ds, 'Reference', URI: reference.uri) do
          @xml_helper.build_child(xml, :ds, 'Transforms') do
            @xml_helper.build_child(xml, :ds, 'Transform',
                                    Algorithm: @canonicalizer.algorithm_id) do
              if reference.inclusive_namespaces?
                xml['ec'].InclusiveNamespaces(
                  'xmlns:ec' => NS_EC,
                  PrefixList: reference.prefix_list
                )
              end
            end
          end
          @xml_helper.build_child(xml, :ds, 'DigestMethod', Algorithm: @digester.algorithm_id)
          @xml_helper.build_child(xml, :ds, 'DigestValue', reference.digest_value)
        end
      end

      # Computes the signature value.
      #
      # @param canonical_signed_info [String] the canonicalized SignedInfo XML
      # @return [String] the Base64-encoded signature value
      #
      def compute_signature(canonical_signed_info)
        digest = OpenSSL::Digest.new(@signature_algorithm[:digest])
        signature = @private_key.sign(digest, canonical_signed_info)
        Base64.strict_encode64(signature)
      end

      # Builds and inserts the complete Signature element into the Security header.
      #
      # @param document [Nokogiri::XML::Document] the SOAP document
      # @param security_node [Nokogiri::XML::Node] the wsse:Security element
      # @param signed_info [Nokogiri::XML::Node] the SignedInfo element
      # @param signature_value [String] the computed signature value
      #
      def build_signature_element(_document, security_node, signed_info, signature_value)
        # Add BinarySecurityToken if using that key reference method
        if @key_reference == KeyReference::BINARY_SECURITY_TOKEN
          bst = build_binary_security_token
          security_node.add_child(bst)
        end

        # Build complete Signature element
        signature_node = build_signature_node(signature_value)

        # Insert SignedInfo as first child of Signature
        signature_node.children.first.add_previous_sibling(signed_info)

        # Add Signature to Security header (after BinarySecurityToken if present)
        security_node.add_child(signature_node)
      end

      # Builds the Signature node.
      #
      # @param signature_value [String] the computed signature value
      # @return [Nokogiri::XML::Node]
      #
      def build_signature_node(signature_value)
        builder = Nokogiri::XML::Builder.new do |xml|
          @xml_helper.build_element(xml, :ds, 'Signature') do
            # SignedInfo will be imported
            @xml_helper.build_child(xml, :ds, 'SignatureValue', signature_value)
            build_key_info(xml)
          end
        end

        builder.doc.root
      end

      # Builds the KeyInfo element based on key_reference method.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      #
      def build_key_info(xml)
        @xml_helper.build_child(xml, :ds, 'KeyInfo') do
          xml['wsse'].SecurityTokenReference('xmlns:wsse' => NS_WSSE) do
            case @key_reference
            when KeyReference::BINARY_SECURITY_TOKEN
              build_bst_reference(xml)
            when KeyReference::ISSUER_SERIAL
              build_issuer_serial_reference(xml)
            when KeyReference::SUBJECT_KEY_IDENTIFIER
              build_ski_reference(xml)
            end
          end
        end
      end

      # Builds a reference to the BinarySecurityToken.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      #
      def build_bst_reference(xml)
        xml['wsse'].Reference(
          URI: "##{@security_token_id}",
          ValueType: X509_V3_URI
        )
      end

      # Builds an IssuerSerial reference.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      #
      def build_issuer_serial_reference(xml)
        @xml_helper.build_child_with_ns(xml, :ds, 'X509Data') do
          @xml_helper.build_child(xml, :ds, 'X509IssuerSerial') do
            @xml_helper.build_child(xml, :ds, 'X509IssuerName', issuer_name)
            @xml_helper.build_child(xml, :ds, 'X509SerialNumber', serial_number)
          end
        end
      end

      # Builds a Subject Key Identifier reference.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      #
      def build_ski_reference(xml)
        xml['wsse'].KeyIdentifier(
          encoded_subject_key_identifier,
          'ValueType' => X509_SKI_URI,
          'EncodingType' => BASE64_ENCODING_URI
        )
      end

      # Returns the issuer distinguished name from the certificate.
      #
      # @return [String] the issuer DN in RFC 2253 format
      #
      def issuer_name
        @certificate.issuer.to_s(OpenSSL::X509::Name::RFC2253)
      end

      # Returns the certificate serial number.
      #
      # @return [String] the serial number as a string
      #
      def serial_number
        @certificate.serial.to_s
      end

      # Returns the Base64-encoded Subject Key Identifier.
      #
      # @return [String] the encoded SKI
      # @raise [RuntimeError] if certificate doesn't have SKI extension
      #
      def encoded_subject_key_identifier
        ski = extract_subject_key_identifier
        raise 'Certificate does not have Subject Key Identifier extension' unless ski

        # Convert hex string to binary and encode as Base64
        binary_ski = [ski].pack('H*')
        Base64.strict_encode64(binary_ski)
      end

      # Extracts the Subject Key Identifier from the certificate.
      #
      # @return [String, nil] the SKI as a hex string, or nil if not present
      #
      def extract_subject_key_identifier
        @certificate.extensions.each do |ext|
          return ext.value.delete(':') if ext.oid == 'subjectKeyIdentifier'
        end
        nil
      end

      # Builds the BinarySecurityToken element.
      #
      # @return [Nokogiri::XML::Node] the BinarySecurityToken element
      #
      def build_binary_security_token
        builder = Nokogiri::XML::Builder.new do |xml|
          xml['wsse'].BinarySecurityToken(
            'xmlns:wsse' => NS_WSSE,
            'xmlns:wsu' => NS_WSU,
            'wsu:Id' => @security_token_id,
            'ValueType' => X509_V3_URI,
            'EncodingType' => BASE64_ENCODING_URI
          ) do
            xml.text(encoded_certificate)
          end
        end

        builder.doc.root
      end
    end
  end
end
