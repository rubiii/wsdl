# frozen_string_literal: true

require 'nokogiri'
require 'date'
require 'wsdl/xml/parser'
require 'base64'
require 'bigdecimal'

module WSDL
  class Response
    # Converts XML documents to Ruby Hashes with optional schema-aware parsing.
    #
    # This class provides a unified way to parse XML into nested Hashes with
    # symbolized keys. When schema information is provided, values are automatically
    # converted to appropriate Ruby types and arrays are handled consistently
    # based on the schema's maxOccurs definitions.
    #
    # Namespace prefixes are stripped from element names, but the original
    # casing is preserved.
    #
    # @example Basic usage (no schema)
    #   xml = "<Envelope><Body><Result>42</Result></Body></Envelope>"
    #   hash = WSDL::Response::HashConverter.parse(xml)
    #   # => { Envelope: { Body: { Result: "42" } } }
    #
    # @example Parsing a Nokogiri node
    #   doc = WSDL::XML::Parser.parse(xml)
    #   hash = WSDL::Response::HashConverter.parse(doc.root)
    #
    # @example Schema-aware parsing with type coercion
    #   hash = WSDL::Response::HashConverter.parse(body_node, schema: output_parts)
    #   # => { Order: { Id: 123, Items: [{ Name: "Widget" }] } }
    #
    # @see WSDL::Response
    # @see WSDL::XML::Element
    #
    class HashConverter
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
        'boolean' => :convert_boolean,

        # Date/time types
        'date' => :convert_date,
        'dateTime' => :convert_datetime,
        'time' => :convert_time,

        # Binary types
        'base64Binary' => :convert_base64,
        'hexBinary' => :convert_hex_binary
      }.freeze

      class << self
        # Parses XML into a Hash with optional schema-aware type coercion.
        #
        # When schema elements are provided, values are converted to appropriate
        # Ruby types (Integer, Float, BigDecimal, Date, Time, Boolean, etc.) and
        # elements with maxOccurs > 1 are always returned as arrays.
        #
        # When no schema is provided, all values are returned as strings and
        # repeated elements are converted to arrays only when multiple elements
        # with the same name are present.
        #
        # @param xml [String, Nokogiri::XML::Document, Nokogiri::XML::Node]
        #   the XML to parse
        # @param schema [Array<WSDL::XML::Element>, nil] optional schema elements
        #   describing the expected structure for type-aware parsing
        # @return [Hash] the parsed XML as a nested Hash with symbolized keys
        #
        # @example Without schema
        #   HashConverter.parse("<Root><Value>42</Value></Root>")
        #   # => { Root: { Value: "42" } }
        #
        # @example With schema
        #   HashConverter.parse(node, schema: elements)
        #   # => { Root: { Value: 42 } }  # Integer if schema says xsd:int
        #
        def parse(xml, schema: nil)
          node = resolve_node(xml)
          return {} unless node

          new(schema:).convert_node(node)
        end

        private

        # Resolves the input to a Nokogiri XML node.
        #
        # @param xml [String, Nokogiri::XML::Document, Nokogiri::XML::Node]
        # @return [Nokogiri::XML::Node, nil]
        #
        def resolve_node(xml)
          case xml
          when Nokogiri::XML::Document then xml.root
          when Nokogiri::XML::Node then xml
          when String then WSDL::XML::Parser.parse(xml).root
          end
        end
      end

      # Creates a new HashConverter instance.
      #
      # @param schema [Array<WSDL::XML::Element>, nil] optional schema elements
      #
      # @api private
      #
      def initialize(schema: nil)
        @schema = schema
        @schema_map = build_schema_map(schema) if schema
      end

      # Converts an XML node to a Hash.
      #
      # This is the main entry point for conversion. It wraps the node's
      # content in a hash with the node's local name as the key.
      #
      # @param node [Nokogiri::XML::Node] the XML node to convert
      # @return [Hash] the converted hash
      #
      # @api private
      #
      def convert_node(node)
        key = node.name.to_sym
        value = @schema ? convert_with_schema(node, @schema) : convert_without_schema(node)

        { key => value }
      end

      private

      # Builds a lookup map from element names to schema elements.
      #
      # @param schema [Array<WSDL::XML::Element>]
      # @return [Hash<String, WSDL::XML::Element>]
      #
      def build_schema_map(schema)
        return {} unless schema

        schema.to_h do |element|
          [element.name, element]
        end
      end

      # Converts an XML node without schema information.
      #
      # All values are returned as strings. Repeated elements with the
      # same name are converted to arrays.
      #
      # @param node [Nokogiri::XML::Node] the XML node
      # @return [Hash, String] the converted content
      #
      def convert_without_schema(node)
        children = node.element_children
        return node.text if children.empty?

        children.each_with_object({}) do |child, result|
          key = child.name.to_sym
          value = convert_without_schema(child)

          if result.key?(key)
            result[key] = [result[key]] unless result[key].is_a?(Array)
            result[key] << value
          else
            result[key] = value
          end
        end
      end

      # Converts an XML node using schema information.
      #
      # Values are converted to appropriate Ruby types based on the schema.
      # Elements with maxOccurs > 1 are always returned as arrays.
      #
      # @param node [Nokogiri::XML::Node] the XML node
      # @param schema_elements [Array<WSDL::XML::Element>] expected child elements
      # @return [Hash, String, Object] the converted content
      #
      def convert_with_schema(node, schema_elements)
        children = node.element_children
        return node.text if children.empty? && schema_elements.empty?

        xml_children = children.group_by(&:name)
        result = {}

        process_schema_elements(schema_elements, xml_children, result)
        process_unknown_elements(xml_children, result)

        result
      end

      # Processes XML elements that match schema definitions.
      #
      # @param schema_elements [Array<WSDL::XML::Element>] expected schema elements
      # @param xml_children [Hash<String, Array>] grouped XML children (mutated)
      # @param result [Hash] the result hash to populate
      #
      def process_schema_elements(schema_elements, xml_children, result)
        schema_elements.each do |schema_el|
          xml_nodes = xml_children.delete(schema_el.name) || []
          next if xml_nodes.empty?

          key = schema_el.name.to_sym
          values = xml_nodes.map { |xml_node| convert_element(xml_node, schema_el) }

          result[key] = schema_el.singular? ? values.first : values
        end
      end

      # Processes XML elements not defined in the schema.
      #
      # @param xml_children [Hash<String, Array>] remaining XML children
      # @param result [Hash] the result hash to populate
      #
      def process_unknown_elements(xml_children, result)
        xml_children.each do |name, nodes|
          key = name.to_sym
          values = nodes.map { |n| convert_without_schema(n) }
          result[key] = values.size == 1 ? values.first : values
        end
      end

      # Converts a single element using its schema definition.
      #
      # @param xml_node [Nokogiri::XML::Element] the XML element
      # @param schema_el [WSDL::XML::Element] the schema element
      # @return [Object] the parsed value (String, Integer, Hash, etc.)
      #
      def convert_element(xml_node, schema_el)
        return nil if xsi_nil?(xml_node)

        if schema_el.simple_type?
          convert_value(xml_node.text, schema_el.base_type)
        elsif schema_el.complex_type?
          convert_with_schema(xml_node, schema_el.children)
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

      # Converts a string value to the appropriate Ruby type.
      #
      # @param value [String] the string value from XML
      # @param type [String] the XSD type (e.g., "xsd:int", "xs:string")
      # @return [Object] the converted value
      #
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
      #
      def convert_integer(value)
        Integer(value)
      rescue ArgumentError
        value
      end

      # Converts a value to BigDecimal.
      #
      # @param value [String] the string value
      # @return [BigDecimal, String] the decimal or original string if invalid
      #
      def convert_decimal(value)
        BigDecimal(value)
      rescue ArgumentError
        value
      end

      # Converts a value to Float.
      #
      # @param value [String] the string value
      # @return [Float, String] the float or original string if invalid
      #
      def convert_float(value)
        Float(value)
      rescue ArgumentError
        value
      end

      # Converts a string value to Boolean.
      #
      # @param value [String] the string value
      # @return [Boolean] true or false
      #
      # rubocop:disable Naming/PredicateMethod
      def convert_boolean(value)
        %w[true 1].include?(value)
      end
      # rubocop:enable Naming/PredicateMethod

      # Converts a value to Date.
      #
      # @param value [String] the string value (ISO 8601 format)
      # @return [Date, String] the date or original string if invalid
      #
      def convert_date(value)
        Date.parse(value)
      rescue ArgumentError
        value
      end

      # Converts a value to Time (for xsd:dateTime).
      #
      # @param value [String] the string value (ISO 8601 format)
      # @return [Time, String] the time or original string if invalid
      #
      def convert_datetime(value)
        Time.parse(value)
      rescue ArgumentError
        value
      end

      # Converts a value to Time (for xsd:time).
      #
      # @param value [String] the string value
      # @return [Time, String] the time or original string if invalid
      #
      def convert_time(value)
        Time.parse(value)
      rescue ArgumentError
        value
      end

      # Converts a base64-encoded value to a decoded string.
      #
      # @param value [String] the base64-encoded string
      # @return [String] the decoded binary string
      #
      def convert_base64(value)
        Base64.decode64(value)
      end

      # Converts a hex-encoded value to a decoded string.
      #
      # @param value [String] the hex-encoded string
      # @return [String] the decoded binary string
      #
      def convert_hex_binary(value)
        [value].pack('H*')
      end
    end
  end
end
