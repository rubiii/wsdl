# frozen_string_literal: true

class WSDL
  class XS
    # Base class for all XML Schema type representations.
    #
    # Provides common functionality for parsing XSD nodes, accessing
    # child elements, and collecting nested elements and attributes
    # from the type hierarchy.
    #
    class BaseType
      # Creates a new BaseType from an XML Schema node.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context (target namespace, form defaults)
      def initialize(node, schemas, schema = {})
        @node = node
        @schemas = schemas
        @schema = schema
      end

      # @return [Nokogiri::XML::Node] the underlying XML node
      attr_reader :node

      # Returns an attribute value from the underlying node.
      #
      # @param key [String] the attribute name
      # @return [String, nil] the attribute value
      def [](key)
        @node[key]
      end

      # Returns whether this type has no meaningful content.
      #
      # @return [Boolean] true if there are no children or the first child is empty
      def empty?
        children.empty? || children.first.empty?
      end

      # Returns the parsed child elements of this type.
      #
      # Child elements are recursively parsed into their appropriate
      # XS type classes.
      #
      # @return [Array<BaseType>] the parsed child type objects
      def children
        @children ||= @node.element_children.map { |child| XS.build(child, @schemas, @schema) }
      end

      # Recursively collects all element definitions from this type and its children.
      #
      # Traverses the type hierarchy to find all xs:element definitions,
      # which represent the actual content model of complex types.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Element>] all element definitions found
      def collect_child_elements(memo = [])
        children.each do |child|
          if child.is_a?(Element) || child.is_a?(Any)
            # Collect both regular elements and xs:any wildcards.
            # The Any wildcards are handled specially downstream to allow
            # arbitrary content in the generated XML.
            memo << child
          else
            memo = child.collect_child_elements(memo)
          end
        end

        memo
      end

      # Recursively collects all attribute definitions from this type and its children.
      #
      # Traverses the type hierarchy to find all xs:attribute definitions.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Attribute>] all attribute definitions found
      def collect_attributes(memo = [])
        children.each do |child|
          if child.is_a? Attribute
            memo << child
          else
            memo = child.collect_attributes(memo)
          end
        end

        memo
      end

      # Returns a string representation of this type for debugging.
      #
      # @return [String] a formatted string with the class name and node attributes
      def inspect
        attributes = @node
          .attributes
          .each_with_object({}) { |(k, attr), memo|
            memo[k.to_s] = attr.value
          }

        formatted_attributes = attributes
          .map { |k, v| format('%<key>s="%<value>s"', key: k, value: v) }
          .join(' ')

        format('<%<class>s %<attributes>s>', class: self.class, attributes: formatted_attributes)
      end
    end
  end
end
