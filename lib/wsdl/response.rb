# frozen_string_literal: true

module WSDL
  # Represents a SOAP response from an operation call.
  #
  # This class wraps the raw HTTP response and provides methods
  # for parsing and accessing the SOAP envelope contents. When
  # schema information is available, response values are automatically
  # converted to appropriate Ruby types and arrays are handled
  # consistently based on the schema's maxOccurs definitions.
  #
  # @example Accessing the response body
  #   response = operation.call
  #   puts response.body[:get_user_response][:user][:name]
  #
  # @example Working with the raw response
  #   response = operation.call
  #   puts response.raw  # Raw XML string
  #
  # @example Using XPath queries
  #   response = operation.call
  #   users = response.xpath('//ns:User', 'ns' => 'http://example.com/users')
  #   users.each { |user| puts user.text }
  #
  # @example Type conversions (with schema)
  #   response = operation.call
  #   response.body[:order][:id]       # => 123 (Integer, not "123")
  #   response.body[:order][:total]    # => BigDecimal("99.99")
  #   response.body[:order][:shipped]  # => true (Boolean, not "true")
  #   response.body[:order][:items]    # => [{ name: "Widget" }] (always Array)
  #
  # @example Verifying signature
  #   response = operation.call
  #   if response.signature_present?
  #     if response.signature_valid?
  #       puts "Response is signed and valid"
  #       puts "Signed elements: #{response.signed_elements}"
  #     else
  #       puts "Signature verification failed: #{response.signature_errors}"
  #     end
  #   end
  #
  class Response
    # Creates a new Response instance.
    #
    # @param raw_response [String] the raw HTTP response body (XML)
    # @param output_body_parts [Array<WSDL::XML::Element>, nil] optional schema elements
    #   describing the expected body structure for type-aware parsing
    # @param output_header_parts [Array<WSDL::XML::Element>, nil] optional schema elements
    #   describing the expected header structure for type-aware parsing
    # @param verify_certificate [OpenSSL::X509::Certificate, nil] optional certificate
    #   to use for signature verification instead of extracting from message
    def initialize(raw_response, output_body_parts: nil, output_header_parts: nil, verify_certificate: nil)
      @raw_response = raw_response
      @output_body_parts = output_body_parts
      @output_header_parts = output_header_parts
      @verify_certificate = verify_certificate
      @verifier = nil
    end

    # Returns the raw XML response string.
    #
    # @return [String] the raw XML response body
    def raw
      @raw_response
    end

    # Returns the parsed SOAP body as a Hash.
    #
    # When schema information is available (output_body_parts), values are
    # automatically converted to appropriate Ruby types:
    # - xsd:int, xsd:integer, xsd:long → Integer
    # - xsd:decimal → BigDecimal
    # - xsd:float, xsd:double → Float
    # - xsd:boolean → true/false
    # - xsd:date → Date
    # - xsd:dateTime → Time
    # - xsd:base64Binary → decoded String
    #
    # Elements with maxOccurs > 1 are always returned as Arrays,
    # even when only one element is present.
    #
    # @return [Hash] the parsed body content
    # @example
    #   response.body
    #   # => { GetUserResponse: { User: { Name: "John", Age: 30 } } }
    def body
      @body ||= parse_body
    end
    alias to_hash body

    # Returns the parsed SOAP header as a Hash.
    #
    # When schema information is available (output_header_parts), values are
    # automatically converted to appropriate Ruby types, similar to {#body}.
    #
    # The header is extracted from the SOAP envelope and returned
    # with symbolized keys preserving the original element names.
    #
    # @return [Hash, nil] the parsed header content, or nil if empty
    def header
      @header ||= parse_header
    end

    # Returns the entire parsed SOAP envelope as a Hash.
    #
    # Keys are symbolized, preserving original element names.
    # Note: This method does not use schema-aware parsing.
    # Use {#body} and {#header} for schema-aware access.
    #
    # @return [Hash] the complete parsed envelope
    def hash
      @hash ||= HashConverter.parse(doc)
    end

    # Returns the response as a Nokogiri XML document.
    #
    # Use this when you need full XML manipulation capabilities
    # or want to run XPath queries.
    #
    # @return [Nokogiri::XML::Document] the parsed XML document
    def doc
      @doc ||= Nokogiri.XML(raw)
    end

    # Executes an XPath query on the response document.
    #
    # @param path [String] the XPath expression
    # @param namespaces [Hash, nil] optional namespace mappings
    #   (defaults to the namespaces declared in the document)
    # @return [Nokogiri::XML::NodeSet] the matching nodes
    # @example Without custom namespaces
    #   response.xpath('//User')
    # @example With custom namespaces
    #   response.xpath('//ns:User', 'ns' => 'http://example.com/users')
    def xpath(path, namespaces = nil)
      doc.xpath(path, namespaces || xml_namespaces)
    end

    # Returns all XML namespaces declared in the response document.
    #
    # This is useful for building XPath queries that need to
    # reference namespaced elements.
    #
    # @return [Hash<String, String>] namespace prefix to URI mappings
    # @example
    #   response.xml_namespaces
    #   # => { "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
    #   #      "xmlns:ns1" => "http://example.com/users" }
    def xml_namespaces
      @xml_namespaces ||= doc.collect_namespaces
    end

    # ============================================================
    # Signature Verification Methods
    # ============================================================

    # Returns whether the response contains a signature.
    #
    # @return [Boolean] true if a ds:Signature element is present
    #
    # @example
    #   if response.signature_present?
    #     puts "Response is signed"
    #   end
    def signature_present?
      verifier.signature_present?
    end

    # Returns whether the response signature is valid.
    #
    # This performs full signature verification including:
    # - Locating the signing certificate (from BinarySecurityToken or provided)
    # - Verifying all Reference digests match the signed elements
    # - Verifying the SignatureValue over the canonicalized SignedInfo
    #
    # Returns false if no signature is present. Use {#signature_present?}
    # to distinguish between "no signature" and "invalid signature".
    #
    # @return [Boolean] true if signature is present and valid
    #
    # @example
    #   if response.signature_valid?
    #     # Safe to trust the response content
    #   else
    #     puts "Errors: #{response.signature_errors}"
    #   end
    def signature_valid?
      verifier.valid?
    end

    # Verifies the signature and raises an error if invalid.
    #
    # Use this method when you want to ensure the response is properly
    # signed and fail loudly if it's not.
    #
    # @raise [SignatureVerificationError] if signature is missing or invalid
    # @return [true] if signature is valid
    #
    # @example
    #   begin
    #     response.verify_signature!
    #     # Process trusted response
    #   rescue WSDL::SignatureVerificationError => e
    #     puts "Untrusted response: #{e.message}"
    #   end
    def verify_signature!
      raise SignatureVerificationError, 'Response does not contain a signature' unless signature_present?

      unless signature_valid?
        errors = signature_errors.join('; ')
        raise SignatureVerificationError, "Signature verification failed: #{errors}"
      end

      true
    end

    # Returns the IDs of all signed elements.
    #
    # These are the URI references from the signature's Reference elements,
    # typically including Body, Timestamp, and possibly WS-Addressing headers.
    #
    # @return [Array<String>] element IDs (e.g., ['Body-abc123', 'Timestamp-xyz789'])
    #
    # @example
    #   response.signed_element_ids
    #   # => ["Body-abc123", "Timestamp-xyz789"]
    def signed_element_ids
      verifier.signed_element_ids
    end

    # Returns the names of all signed elements.
    #
    # @return [Array<String>] element names (e.g., ['Body', 'Timestamp'])
    #
    # @example
    #   response.signed_elements
    #   # => ["Body", "Timestamp"]
    def signed_elements
      verifier.signed_elements
    end

    # Returns any errors from signature verification.
    #
    # This is populated after calling {#signature_valid?} and contains
    # details about why verification failed.
    #
    # @return [Array<String>] error messages
    #
    # @example
    #   unless response.signature_valid?
    #     response.signature_errors.each do |error|
    #       puts "Verification error: #{error}"
    #     end
    #   end
    def signature_errors
      verifier.errors
    end

    # Returns the signature algorithm used.
    #
    # @return [String, nil] the algorithm URI (e.g., 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
    def signature_algorithm
      verifier.signature_algorithm
    end

    # Returns the digest algorithm used.
    #
    # @return [String, nil] the algorithm URI from the first reference
    def digest_algorithm
      verifier.digest_algorithm
    end

    # Returns the certificate used to sign the response.
    #
    # This is either the certificate extracted from the BinarySecurityToken
    # in the response, or the certificate provided at initialization.
    #
    # @return [OpenSSL::X509::Certificate, nil] the signing certificate
    def signing_certificate
      # Trigger verification to extract certificate
      verifier.valid? unless verifier.certificate
      verifier.certificate
    end

    private

    # Parses the SOAP body using schema information if available.
    #
    # @return [Hash] the parsed body content
    #
    def parse_body
      body_node = find_soap_body
      return {} unless body_node

      if @output_body_parts&.any?
        parse_envelope_part(body_node, @output_body_parts)
      else
        envelope_hash = HashConverter.parse(doc)
        envelope_hash.dig(:Envelope, :Body) || {}
      end
    end

    # Parses the SOAP header using schema information if available.
    #
    # @return [Hash, nil] the parsed header content
    #
    def parse_header
      header_node = find_soap_header
      return nil unless header_node

      if @output_header_parts&.any?
        parse_envelope_part(header_node, @output_header_parts)
      else
        envelope_hash = hash
        envelope_hash.dig(:Envelope, :Header)
      end
    end

    # Parses an envelope part (body or header) with schema information.
    #
    # @param node [Nokogiri::XML::Element] the envelope part node
    # @param schema_parts [Array<WSDL::XML::Element>] the schema elements
    # @return [Hash] the parsed content
    #
    def parse_envelope_part(node, schema_parts)
      xml_children = node.element_children.group_by(&:name)
      result = {}

      parse_schema_elements(schema_parts, xml_children, result)
      parse_unknown_elements(xml_children, result)

      result
    end

    # Parses XML elements that match schema definitions.
    #
    # @param schema_parts [Array<WSDL::XML::Element>] schema elements
    # @param xml_children [Hash<String, Array>] grouped XML children
    # @param result [Hash] the result hash to populate
    #
    def parse_schema_elements(schema_parts, xml_children, result)
      schema_parts.each do |schema_el|
        xml_nodes = xml_children.delete(schema_el.name) || []
        next if xml_nodes.empty?

        key = schema_el.name.to_sym
        values = xml_nodes.map { |xml_node| convert_schema_element(xml_node, schema_el) }

        result[key] = schema_el.singular? ? values.first : values
      end
    end

    # Parses XML elements not defined in the schema.
    #
    # @param xml_children [Hash<String, Array>] remaining XML children
    # @param result [Hash] the result hash to populate
    #
    def parse_unknown_elements(xml_children, result)
      xml_children.each do |name, nodes|
        key = name.to_sym
        values = nodes.map { |n| HashConverter.parse(n).values.first }
        result[key] = values.size == 1 ? values.first : values
      end
    end

    # Converts a schema element from XML.
    #
    # @param xml_node [Nokogiri::XML::Element] the XML element
    # @param schema_el [WSDL::XML::Element] the schema element definition
    # @return [Object] the converted value
    #
    def convert_schema_element(xml_node, schema_el)
      return nil if xsi_nil?(xml_node)

      if schema_el.simple_type?
        convert_typed_value(xml_node.text, schema_el.base_type)
      elsif schema_el.complex_type?
        parse_envelope_part(xml_node, schema_el.children)
      else
        xml_node.text
      end
    end

    # Checks if an element has xsi:nil="true".
    #
    # @param node [Nokogiri::XML::Element] the XML element
    # @return [Boolean] true if the element is nil
    #
    def xsi_nil?(node)
      nil_attr = node.attribute_with_ns('nil', 'http://www.w3.org/2001/XMLSchema-instance')
      nil_attr&.value == 'true'
    end

    # Converts a typed value using XSD type information.
    #
    # @param value [String] the string value
    # @param type [String] the XSD type (e.g., "xsd:int")
    # @return [Object] the converted value
    #
    def convert_typed_value(value, type)
      return value if value.nil? || value.empty?

      local_type = type&.split(':')&.last
      converter = HashConverter::TYPE_CONVERTERS[local_type]

      return value if converter.nil? || converter == :to_s

      # Create a temporary converter instance to use conversion methods
      HashConverter.new.send(:send, converter, value)
    end

    # Finds the SOAP Body element in the document.
    #
    # @return [Nokogiri::XML::Element, nil] the Body element
    #
    def find_soap_body
      doc.at_xpath(
        '//soap:Body | //soap12:Body | //env:Body',
        'soap' => NS::SOAP_1_1,
        'soap12' => NS::SOAP_1_2,
        'env' => NS::SOAP_1_1
      )
    end

    # Finds the SOAP Header element in the document.
    #
    # @return [Nokogiri::XML::Element, nil] the Header element
    #
    def find_soap_header
      doc.at_xpath(
        '//soap:Header | //soap12:Header | //env:Header',
        'soap' => NS::SOAP_1_1,
        'soap12' => NS::SOAP_1_2,
        'env' => NS::SOAP_1_1
      )
    end

    # Returns the signature verifier instance.
    #
    # @return [Security::Verifier]
    #
    def verifier
      @verifier ||= Security::Verifier.new(@raw_response, certificate: @verify_certificate)
    end
  end
end
