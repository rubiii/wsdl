# frozen_string_literal: true

require 'nokogiri'
require 'date'
require 'base64'
require 'bigdecimal'

class WSDL
  # Schema-aware XML response parser.
  #
  # This class parses SOAP response XML using schema information from the WSDL
  # to provide proper type coercion and consistent array handling. When schema
  # information is available, it converts XSD types to appropriate Ruby types
  # and ensures elements with maxOccurs > 1 are always returned as arrays,
  # even when only one element is present.
  #
  # For elements not defined in the schema, the parser falls back to returning
  # string values, ensuring graceful handling of unexpected response content.
  #
  # @example Parsing with schema information
  #   parser = WSDL::ResponseParser.new(output_parts)
  #   result = parser.parse(nokogiri_doc)
  #   # => { Order: { Id: 123, Items: [{ Name: "Widget" }] } }
  #
  # @see WSDL::Response
  # @see WSDL::XML::Element
  #
  class ResponseParser
    # Mapping of XSD type local names to conversion methods.
    #
    # @api private
    TYPE_CONVERTERS = {
      # String types
      'string' => :to_s,
      'normalizedString' => :to_s,
      'token' => :to_s,
      'language' => :to_s,
      'Name' => :to_s,
      'NCName' => :to_s,
      'ID' => :to_s,
      'IDREF' => :to_s,
      'ENTITY' => :to_s,
      'NMTOKEN' => :to_s,
      'anyURI' => :to_s,
      'QName' => :to_s,

      # Integer types
      'integer' => :convert_integer,
      'int' => :convert_integer,
      'long' => :convert_integer,
      'short' => :convert_integer,
      'byte' => :convert_integer,
      'nonNegativeInteger' => :convert_integer,
      'positiveInteger' => :convert_integer,
      'nonPositiveInteger' => :convert_integer,
      'negativeInteger' => :convert_integer,
      'unsignedLong' => :convert_integer,
      'unsignedInt' => :convert_integer,
      'unsignedShort' => :convert_integer,
      'unsignedByte' => :convert_integer,

      # Decimal/float types
      'decimal' => :convert_decimal,
      'float' => :convert_float,
      'double' => :convert_float,

      # Boolean
      'boolean' => :parse_boolean,

      # Date/time types
      'date' => :convert_date,
      'dateTime' => :convert_time,
      'time' => :convert_time,

      # Binary types
      'base64Binary' => :convert_base64,
      'hexBinary' => :convert_hex_binary
    }.freeze

    # Creates a new ResponseParser instance.
    #
    # @param output_parts [Array<WSDL::XML::Element>] the schema elements
    #   describing the expected response structure
    def initialize(output_parts)
      @output_parts = output_parts
    end

    # Parses the SOAP body content using schema information.
    #
    # @param doc [Nokogiri::XML::Document] the parsed XML document
    # @return [Hash] the parsed response with proper types and arrays
    def parse(doc)
      body = find_soap_body(doc)
      return {} unless body

      parse_children(body, @output_parts)
    end

    private

    # Finds the SOAP Body element in the document.
    #
    # @param doc [Nokogiri::XML::Document] the XML document
    # @return [Nokogiri::XML::Element, nil] the Body element
    def find_soap_body(doc)
      doc.at_xpath(
        '//soap:Body | //soap12:Body | //env:Body',
        'soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
        'soap12' => 'http://www.w3.org/2003/05/soap-envelope',
        'env' => 'http://schemas.xmlsoap.org/soap/envelope/'
      )
    end

    # Parses child elements of a node using schema information.
    #
    # @param node [Nokogiri::XML::Element] the parent XML node
    # @param schema_elements [Array<WSDL::XML::Element>] expected child elements
    # @return [Hash] parsed children as a hash
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def parse_children(node, schema_elements)
      result = {}

      # Group XML children by local name
      xml_children = node.element_children.group_by(&:name)

      # Process each expected schema element
      schema_elements.each do |schema_el|
        xml_nodes = xml_children.delete(schema_el.name) || []
        next if xml_nodes.empty?

        key = schema_el.name.to_sym
        values = xml_nodes.map { |xml_node| parse_element(xml_node, schema_el) }

        # Always wrap in array if schema says it's not singular (maxOccurs > 1)
        result[key] = schema_el.singular? ? values.first : values
      end

      # Handle any unexpected elements not in schema (include as-is)
      xml_children.each do |name, nodes|
        key = name.to_sym
        values = nodes.map { |n| parse_unknown_element(n) }
        result[key] = values.size == 1 ? values.first : values
      end

      result
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Parses a single element using its schema definition.
    #
    # @param xml_node [Nokogiri::XML::Element] the XML element
    # @param schema_el [WSDL::XML::Element] the schema element
    # @return [Object] the parsed value (String, Integer, Hash, etc.)
    def parse_element(xml_node, schema_el)
      return nil if xsi_nil?(xml_node)

      if schema_el.simple_type?
        convert_value(xml_node.text, schema_el.base_type)
      elsif schema_el.complex_type?
        parse_children(xml_node, schema_el.children)
      else
        xml_node.text
      end
    end

    # Parses an element not defined in the schema.
    #
    # Falls back to simple hash conversion without type coercion.
    #
    # @param xml_node [Nokogiri::XML::Element] the XML element
    # @return [String, Hash] the parsed value
    def parse_unknown_element(xml_node)
      children = xml_node.element_children
      return xml_node.text if children.empty?

      result = {}
      children.each do |child|
        key = child.name.to_sym
        value = parse_unknown_element(child)

        if result.key?(key)
          result[key] = [result[key]] unless result[key].is_a?(Array)
          result[key] << value
        else
          result[key] = value
        end
      end
      result
    end

    # Checks if an element has xsi:nil="true".
    #
    # @param node [Nokogiri::XML::Element] the XML element
    # @return [Boolean] true if the element is nil
    def xsi_nil?(node)
      nil_attr = node.attribute_with_ns('nil', 'http://www.w3.org/2001/XMLSchema-instance')
      nil_attr&.value == 'true'
    end

    # Converts a string value to the appropriate Ruby type.
    #
    # @param value [String] the string value from XML
    # @param type [String] the XSD type (e.g., "xsd:int", "xs:string")
    # @return [Object] the converted value
    def convert_value(value, type)
      return value if value.nil? || value.empty?

      local_type = type&.split(':')&.last
      converter = TYPE_CONVERTERS[local_type]

      if converter.nil? || converter == :to_s
        value
      else
        send(converter, value)
      end
    end

    # Converts a value to Integer.
    #
    # @param value [String] the string value
    # @return [Integer, String] the integer or original string if invalid
    def convert_integer(value)
      Integer(value)
    rescue ArgumentError
      value
    end

    # Converts a value to BigDecimal.
    #
    # @param value [String] the string value
    # @return [BigDecimal, String] the decimal or original string if invalid
    def convert_decimal(value)
      BigDecimal(value)
    rescue ArgumentError
      value
    end

    # Converts a value to Float.
    #
    # @param value [String] the string value
    # @return [Float, String] the float or original string if invalid
    def convert_float(value)
      Float(value)
    rescue ArgumentError
      value
    end

    # Parses a string value into a Boolean.
    #
    # @param value [String] the string value
    # @return [Boolean] true or false
    def parse_boolean(value)
      %w[true 1].include?(value)
    end

    # Converts a value to Date.
    #
    # @param value [String] the string value (ISO 8601 format)
    # @return [Date, String] the date or original string if invalid
    def convert_date(value)
      Date.parse(value)
    rescue ArgumentError
      value
    end

    # Converts a value to Time.
    #
    # @param value [String] the string value (ISO 8601 format)
    # @return [Time, String] the time or original string if invalid
    def convert_time(value)
      Time.parse(value)
    rescue ArgumentError
      value
    end

    # Converts a base64-encoded value to a decoded string.
    #
    # @param value [String] the base64-encoded string
    # @return [String] the decoded binary string
    def convert_base64(value)
      Base64.decode64(value)
    end

    # Converts a hex-encoded value to a decoded string.
    #
    # @param value [String] the hex-encoded string
    # @return [String] the decoded binary string
    def convert_hex_binary(value)
      [value].pack('H*')
    end
  end
end
