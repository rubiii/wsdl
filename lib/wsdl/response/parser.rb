# frozen_string_literal: true

require 'wsdl/ns'
require 'wsdl/xml/parser'
require 'wsdl/response/type_coercer'

module WSDL
  class Response
    # Parses XML responses into Ruby Hash structures with optional schema support.
    #
    # @api private
    class Parser
      QName = Data.define(:namespace, :local)

      class << self
        # Parses XML into a nested hash.
        #
        # @param xml [String, Nokogiri::XML::Document, Nokogiri::XML::Node]
        # @param schema [Array<WSDL::XML::Element>, nil] optional schema for type-aware parsing
        # @param unwrap [Boolean] whether to return only the root element value
        # @return [Hash, Object] parsed hash, or unwrapped root value when unwrap is true
        def parse(xml, schema: nil, unwrap: false)
          node = resolve_node(xml)
          return {} unless node

          parsed = new(schema:).convert_node(node)
          unwrap ? parsed.values.first : parsed
        end

        private

        def resolve_node(xml)
          case xml
          when Nokogiri::XML::Document then xml.root
          when Nokogiri::XML::Node then xml
          when String then WSDL::XML::Parser.parse(xml).root
          end
        end
      end

      # @param schema [Array<WSDL::XML::Element>, nil] optional schema elements
      # @param coercer [#coerce] value coercer used for schema simple types
      def initialize(schema: nil, coercer: TypeCoercer)
        @schema = schema
        @coercer = coercer
      end

      # @param node [Nokogiri::XML::Node] node to parse
      # @return [Hash] parsed node
      def convert_node(node)
        key = node.name.to_sym
        value = @schema ? convert_with_schema(node, @schema) : convert_without_schema(node)
        { key => value }
      end

      private

      def convert_without_schema(node)
        children = node.element_children
        return node.text if children.empty?

        xml_children = group_children_by_qname(children)
        colliding_locals = find_colliding_locals(xml_children.keys)

        xml_children.each_with_object({}) do |(qname, child_nodes), result|
          key = output_key(qname, colliding_locals)
          values = child_nodes.map { |child| convert_without_schema(child) }
          result[key] = child_nodes.one? ? values.first : values
        end
      end

      def convert_with_schema(node, schema_elements)
        schema_elements = Array(schema_elements)
        children = node.element_children
        return node.text if children.empty? && schema_elements.empty?

        xml_children = group_children_by_qname(children)
        colliding_locals = find_colliding_locals(xml_children.keys)
        result = {}

        process_schema_elements(schema_elements, xml_children, colliding_locals, result)
        process_unknown_elements(xml_children, colliding_locals, result)

        result
      end

      def process_schema_elements(schema_elements, xml_children, colliding_locals, result)
        schema_elements.each do |schema_element|
          schema_qname = qname_for_schema_element(schema_element)
          xml_nodes = xml_children.delete(schema_qname) || []
          next if xml_nodes.empty?

          key = output_key(schema_qname, colliding_locals)
          values = xml_nodes.map { |xml_node| convert_element(xml_node, schema_element) }
          result[key] = schema_element.singular? ? values.first : values
        end
      end

      def process_unknown_elements(xml_children, colliding_locals, result)
        xml_children.each do |qname, nodes|
          key = output_key(qname, colliding_locals)
          values = nodes.map { |node| convert_without_schema(node) }
          result[key] = values.size == 1 ? values.first : values
        end
      end

      def convert_element(xml_node, schema_element)
        return nil if xsi_nil?(xml_node)

        if schema_element.simple_type?
          @coercer.coerce(xml_node.text, schema_element.base_type)
        elsif schema_element.complex_type?
          convert_with_schema(xml_node, schema_element.children)
        else
          xml_node.text
        end
      end

      def xsi_nil?(node)
        nil_attr = node.attribute_with_ns('nil', NS::XSI)
        nil_attr&.value == 'true'
      end

      def group_children_by_qname(children)
        children.group_by { |child| qname_for_node(child) }
      end

      def qname_for_node(node)
        QName.new(normalize_namespace(node.namespace&.href), node.name)
      end

      def qname_for_schema_element(schema_element)
        QName.new(schema_namespace(schema_element), schema_element.name)
      end

      def schema_namespace(schema_element)
        return nil if schema_element.form == 'unqualified'

        normalize_namespace(schema_element.namespace)
      end

      def normalize_namespace(namespace)
        return nil if namespace.nil? || namespace.empty?

        namespace
      end

      def find_colliding_locals(qnames)
        qnames
          .group_by(&:local)
          .select { |_local, keys| keys.size > 1 }
          .keys
          .to_set
      end

      def output_key(qname, colliding_locals)
        return qname.local.to_sym unless colliding_locals.include?(qname.local) && qname.namespace

        :"{#{qname.namespace}}#{qname.local}"
      end
    end
  end
end
