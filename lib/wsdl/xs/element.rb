# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:element definition.
    #
    # Elements can be global (top-level) or local (within complex types).
    # They may reference a type via @type attribute, reference another
    # element via @ref, or contain an inline type definition.
    #
    class Element < PrimaryType
      # Creates a new Element with type and ref information.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context information
      def initialize(node, schemas, schema = {})
        super

        @type = node['type']
        @ref  = node['ref']
        @nillable = node['nillable'] == 'true'
      end

      # @return [String, nil] the qualified type name (if using @type attribute)
      attr_reader :type

      # @return [String, nil] the qualified element reference (if using @ref attribute)
      attr_reader :ref

      # @return [Boolean] whether this element allows nil values (xsi:nil="true")
      attr_reader :nillable
      alias nillable? nillable

      # Returns the inline type definition, if any.
      #
      # An inline type is a complex or simple type defined directly within
      # the element rather than referenced by name. Skips annotation elements.
      #
      # @return [ComplexType, SimpleType, nil] the inline type, or nil if none
      def inline_type
        children.detect { |child| child.node.node_name.downcase != 'annotation' }
      end
    end
  end
end
