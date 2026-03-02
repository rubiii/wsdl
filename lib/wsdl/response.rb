# frozen_string_literal: true

require 'wsdl/xml/parser'
require 'wsdl/response/parser'
require 'wsdl/response/security_context'

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
  #   if response.security.signature_present?
  #     if response.security.valid?
  #       puts "Response is signed and valid"
  #       puts "Signed elements: #{response.security.signed_elements}"
  #     else
  #       puts "Signature verification failed: #{response.security.errors}"
  #     end
  #   end
  #
  # @example Strict verification (signature + timestamp)
  #   begin
  #     response.security.verify!
  #   rescue WSDL::SignatureVerificationError => e
  #     puts "Signature error: #{e.message}"
  #   rescue WSDL::TimestampValidationError => e
  #     puts "Timestamp error: #{e.message}"
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
    # @param verification [Security::ResponseVerification] response verification options
    #   for signature and timestamp validation
    #
    def initialize(raw_response, output_body_parts: nil, output_header_parts: nil,
                   verification: Security::ResponseVerification::Options.default)
      @raw_response = raw_response
      @output_body_parts = output_body_parts
      @output_header_parts = output_header_parts
      @verification = verification
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
    # - xsd:dateTime → Time (only when timezone is explicit)
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
    def envelope_hash
      @envelope_hash ||= Parser.parse(doc)
    end
    alias to_envelope_hash envelope_hash

    # Returns the response as a Nokogiri XML document.
    #
    # Use this when you need full XML manipulation capabilities
    # or want to run XPath queries.
    #
    # @return [Nokogiri::XML::Document] the parsed XML document
    def doc
      @doc ||= XML::Parser.parse(raw)
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
    # @return [Hash{String => String}] namespace prefix to URI mappings
    # @example
    #   response.xml_namespaces
    #   # => { "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
    #   #      "xmlns:ns1" => "http://example.com/users" }
    def xml_namespaces
      @xml_namespaces ||= doc.collect_namespaces
    end

    # ============================================================
    # Security Context
    # ============================================================

    # Returns the security context for signature and timestamp verification.
    #
    # The security context provides methods for:
    # - Signature verification (`signature_valid?`, `verify_signature!`)
    # - Timestamp validation (`timestamp_valid?`, `verify_timestamp!`)
    # - Combined verification (`valid?`, `verify!`)
    #
    # @return [SecurityContext] the security verification context
    #
    # @example Check if response is secure
    #   if response.security.valid?
    #     puts "Response is signed and fresh"
    #   end
    #
    # @example Strict verification
    #   response.security.verify!  # raises on failure
    #
    # @example Access verification details
    #   response.security.signed_elements  # => ["Body", "Timestamp"]
    #   response.security.errors           # => ["Digest mismatch..."]
    #
    def security
      @security ||= SecurityContext.new(doc, @verification)
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
        Parser.parse(body_node, schema: @output_body_parts, unwrap: true)
      else
        parsed_envelope = envelope_hash
        parsed_envelope.dig(:Envelope, :Body) || {}
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
        Parser.parse(header_node, schema: @output_header_parts, unwrap: true)
      else
        parsed_envelope = envelope_hash
        parsed_envelope.dig(:Envelope, :Header)
      end
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
  end
end
