# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:attribute definition.
    #
    # Attributes define named value properties on elements. They can
    # be optional or required, and may have default or fixed values.
    #
    class Attribute < BaseType
      # Creates a new Attribute with its properties.
      #
      # @param node [Nokogiri::XML::Node] the XSD attribute node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context information
      def initialize(node, schemas, schema = {})
        super

        @name = node['name']
        @type = node['type']
        @ref  = node['ref']

        @use     = node['use'] || 'optional'
        @default = node['default']
        @fixed   = node['fixed']

        @namespaces = node.namespaces
      end

      # @return [String, nil] the local name of this attribute
      attr_reader :name

      # @return [String, nil] the qualified type name
      attr_reader :type

      # @return [String, nil] the qualified attribute reference (if using @ref)
      attr_reader :ref

      # @return [Hash<String, String>] namespace declarations in scope
      attr_reader :namespaces

      # @return [String] the use constraint ('optional' or 'required')
      attr_reader :use

      # @return [String, nil] the default value for this attribute
      attr_reader :default

      # @return [String, nil] the fixed value for this attribute
      attr_reader :fixed

      # Returns the inline type definition, if any.
      #
      # @return [SimpleType, nil] the inline simple type, or nil if none
      def inline_type
        children.first
      end

      # Stop searching for child elements within attributes.
      #
      # Attributes cannot contain child elements, so this returns
      # an empty array to terminate the recursive search.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end
  end
end
