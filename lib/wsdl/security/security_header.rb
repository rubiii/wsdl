# frozen_string_literal: true

require 'nokogiri'

class WSDL
  module Security
    # Builds the complete wsse:Security header for a SOAP message.
    #
    # The SecurityHeader class orchestrates the construction of the WS-Security
    # header, including:
    # - wsu:Timestamp
    # - wsse:UsernameToken
    # - wsse:BinarySecurityToken (X.509 certificate)
    # - ds:Signature
    #
    # Elements are added in the correct order as required by the WS-Security
    # specification.
    #
    # @example Building a security header
    #   header = SecurityHeader.new(config)
    #   header.apply(document)
    #
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-SOAPMessageSecurity.pdf
    #
    class SecurityHeader
      include Constants

      # Returns the security configuration.
      # @return [Config]
      attr_reader :config

      # Creates a new SecurityHeader instance.
      #
      # @param config [Config] the security configuration
      #
      def initialize(config)
        @config = config
      end

      # Applies the security header to a SOAP document.
      #
      # This method:
      # 1. Parses the SOAP envelope
      # 2. Creates the wsse:Security element in the SOAP Header
      # 3. Adds configured security elements (Timestamp, UsernameToken)
      # 4. If signing is configured, computes digests and adds signature
      #
      # @param envelope_xml [String] the SOAP envelope XML
      # @return [String] the SOAP envelope with security header
      #
      def apply(envelope_xml)
        document = parse_document(envelope_xml)
        header_node = find_or_create_header(document)
        security_node = create_security_element(document, header_node)

        # Add elements to security header
        add_timestamp(document, security_node) if @config.timestamp?
        add_username_token(document, security_node) if @config.username_token?

        # Apply signature if configured (must be last)
        apply_signature(document, security_node) if @config.signature?

        document.to_xml(save_with: xml_save_options)
      end

      private

      # Parses the XML document with whitespace handling for signatures.
      #
      # @param xml [String] the XML string
      # @return [Nokogiri::XML::Document]
      #
      def parse_document(xml)
        Nokogiri::XML(xml, &:noblanks)
      end

      # Returns XML save options.
      #
      # @return [Integer] Nokogiri save options
      #
      def xml_save_options
        Nokogiri::XML::Node::SaveOptions::AS_XML
      end

      # Finds or creates the SOAP Header element.
      #
      # @param document [Nokogiri::XML::Document]
      # @return [Nokogiri::XML::Node]
      #
      def find_or_create_header(document)
        envelope = document.root
        header = envelope.at_xpath('env:Header', 'env' => envelope.namespace.href)

        unless header
          header = Nokogiri::XML::Node.new('Header', document)
          header.namespace = envelope.namespace
          envelope.children.first.add_previous_sibling(header)
        end

        header
      end

      # Creates the wsse:Security element.
      #
      # @param document [Nokogiri::XML::Document]
      # @param header_node [Nokogiri::XML::Node]
      # @return [Nokogiri::XML::Node]
      #
      def create_security_element(document, header_node)
        security = Nokogiri::XML::Node.new('Security', document)
        security.add_namespace_definition('wsse', NS_WSSE)
        security.add_namespace_definition('wsu', NS_WSU)
        security.namespace = security.namespace_definitions.find { |ns| ns.prefix == 'wsse' }

        # Add mustUnderstand attribute (required by WS-Security)
        envelope_ns_prefix = document.root.namespace.prefix || 'env'
        security["#{envelope_ns_prefix}:mustUnderstand"] = '1'

        header_node.add_child(security)
        security
      end

      # Adds a Timestamp element to the security header.
      #
      # @param document [Nokogiri::XML::Document]
      # @param security_node [Nokogiri::XML::Node]
      #
      def add_timestamp(_document, security_node)
        timestamp = @config.timestamp_config

        builder = Nokogiri::XML::Builder.new do |xml|
          xml['wsu'].Timestamp('xmlns:wsu' => NS_WSU, 'wsu:Id' => timestamp.id) do
            xml['wsu'].Created(timestamp.created_at_xml)
            xml['wsu'].Expires(timestamp.expires_at_xml)
          end
        end

        security_node.add_child(builder.doc.root)
      end

      # Adds a UsernameToken element to the security header.
      #
      # @param document [Nokogiri::XML::Document]
      # @param security_node [Nokogiri::XML::Node]
      #
      def add_username_token(_document, security_node)
        token = @config.username_token_config
        builder = build_username_token_xml(token)
        security_node.add_child(builder.doc.root)
      end

      # Builds the UsernameToken XML structure.
      #
      # @param token [UsernameToken] the token configuration
      # @return [Nokogiri::XML::Builder] the builder with token XML
      #
      def build_username_token_xml(token)
        Nokogiri::XML::Builder.new do |xml|
          xml['wsse'].UsernameToken('xmlns:wsse' => NS_WSSE, 'xmlns:wsu' => NS_WSU, 'wsu:Id' => token.id) do
            xml['wsse'].Username(token.username)
            xml['wsse'].Password(token.password_value, 'Type' => token.password_type)
            add_digest_elements(xml, token) if token.digest?
          end
        end
      end

      # Adds digest-specific elements to the UsernameToken.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @param token [UsernameToken] the token configuration
      #
      def add_digest_elements(xml, token)
        xml['wsse'].Nonce(token.encoded_nonce, 'EncodingType' => BASE64_ENCODING_URI)
        xml['wsu'].Created(token.created_at_xml)
      end

      # Applies the digital signature to the document.
      #
      # This method:
      # 1. Adds wsu:Id attributes to elements that will be signed
      # 2. Computes digests for each element
      # 3. Builds and adds the Signature element
      #
      # @param document [Nokogiri::XML::Document]
      # @param security_node [Nokogiri::XML::Node]
      #
      def apply_signature(document, security_node)
        signature = @config.signature_config
        signature.clear_references

        sign_timestamp_if_configured(security_node, signature)
        sign_body_if_configured(document, signature)
        sign_addressing_headers(document, signature) if @config.sign_addressing?

        signature.apply(document, security_node) if signature.references?
      end

      def sign_timestamp_if_configured(security_node, signature)
        return unless @config.sign_timestamp? && @config.timestamp?

        timestamp_node = find_timestamp_node(security_node)
        signature.digest!(timestamp_node) if timestamp_node
      end

      def sign_body_if_configured(document, signature)
        return unless @config.sign_body?

        body_node = find_body_node(document)
        return unless body_node

        body_id = ensure_wsu_id(body_node, 'Body')
        signature.sign_element(body_node, id: body_id)
      end

      # Signs WS-Addressing headers present in the document.
      #
      # This method finds and signs the following WS-Addressing elements if present:
      # - wsa:To - The destination endpoint
      # - wsa:From - The source endpoint
      # - wsa:ReplyTo - Where to send the reply
      # - wsa:FaultTo - Where to send faults
      # - wsa:Action - The operation being invoked
      # - wsa:MessageID - Unique message identifier
      # - wsa:RelatesTo - Correlation to another message
      #
      # Signing these headers prevents routing attacks where an attacker could
      # modify the destination or action of a signed message.
      #
      # @param document [Nokogiri::XML::Document]
      # @param signature [Signature] the signature instance
      #
      def sign_addressing_headers(document, signature)
        header_node = find_header_node(document)
        return unless header_node

        WS_ADDRESSING_HEADERS.each do |header_name|
          # Try the standard WS-Addressing 1.0 namespace first
          node = header_node.at_xpath("wsa:#{header_name}", 'wsa' => NS_WSA)

          # Fall back to 2004/08 namespace if not found
          node ||= header_node.at_xpath("wsa2004:#{header_name}", 'wsa2004' => NS_WSA_2004)

          if node
            header_id = ensure_wsu_id(node, header_name)
            signature.sign_element(node, id: header_id)
          end
        end
      end

      # Finds the SOAP Header element.
      #
      # @param document [Nokogiri::XML::Document]
      # @return [Nokogiri::XML::Node, nil]
      #
      def find_header_node(document)
        envelope = document.root
        envelope.at_xpath('env:Header', 'env' => envelope.namespace.href)
      end

      # Finds the Timestamp node in the security header.
      #
      # @param security_node [Nokogiri::XML::Node]
      # @return [Nokogiri::XML::Node, nil]
      #
      def find_timestamp_node(security_node)
        security_node.at_xpath('wsu:Timestamp', 'wsu' => NS_WSU)
      end

      # Finds the SOAP Body element.
      #
      # @param document [Nokogiri::XML::Document]
      # @return [Nokogiri::XML::Node, nil]
      #
      def find_body_node(document)
        envelope = document.root
        envelope.at_xpath('env:Body', 'env' => envelope.namespace.href)
      end

      # Ensures an element has a wsu:Id attribute.
      #
      # @param node [Nokogiri::XML::Node]
      # @param prefix [String] prefix for generated ID
      # @return [String] the wsu:Id value
      #
      def ensure_wsu_id(node, prefix)
        # Check for existing wsu:Id
        existing_id = node.attribute_with_ns('Id', NS_WSU)&.value
        return existing_id if existing_id

        # Add wsu namespace if not present
        wsu_ns = node.namespace_definitions.find { |ns| ns.href == NS_WSU }
        node.add_namespace_definition('wsu', NS_WSU) unless wsu_ns

        # Generate and set ID
        id = "#{prefix}-#{SecureRandom.uuid}"
        node['wsu:Id'] = id
        id
      end
    end
  end
end
