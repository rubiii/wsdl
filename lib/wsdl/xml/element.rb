# frozen_string_literal: true

class WSDL
  # Namespace for XML-related classes used in SOAP message construction.
  #
  # This module contains classes for representing XML elements and attributes
  # that are used to build SOAP request messages based on WSDL definitions.
  #
  # @api private
  #
  class XML
    # Represents an XML element definition used for building SOAP messages.
    #
    # Elements are the building blocks of SOAP message structures. They can be
    # either simple types (with a base type like string or integer) or complex
    # types (with child elements). Elements track their cardinality (singular
    # vs. array), namespace qualification, and support detection of recursive
    # type definitions.
    #
    # @api private
    #
    class Element
      # Creates a new Element with default values.
      def initialize
        @children    = []
        @attributes  = {}
        @recursive   = false
        @singular    = true
        @any_content = false
        @nillable    = false
      end

      # @!attribute [rw] parent
      #   The parent element in the element tree.
      #   @return [Element, nil] the parent element
      attr_accessor :parent

      # @!attribute [rw] name
      #   The local name of this element.
      #   @return [String] the element name
      attr_accessor :name

      # @!attribute [rw] namespace
      #   The namespace URI for this element.
      #   @return [String, nil] the namespace URI
      attr_accessor :namespace

      # @!attribute [rw] form
      #   The element form ('qualified' or 'unqualified').
      #   Qualified elements include namespace prefixes in the XML output.
      #   @return [String] the element form
      attr_accessor :form

      # Returns whether this element is a simple type.
      #
      # Simple types have a base type and contain only text content,
      # not child elements.
      #
      # @return [Boolean] true if this is a simple type element
      def simple_type?
        !!base_type
      end

      # Returns whether this element is a complex type.
      #
      # Complex types contain child elements rather than simple text content.
      #
      # @return [Boolean] true if this is a complex type element
      def complex_type?
        !simple_type?
      end

      # @!attribute [rw] base_type
      #   The base type name for simple type elements (e.g., 'xsd:string').
      #   @return [String, nil] the base type name, or nil for complex types
      attr_accessor :base_type

      # @!attribute [rw] singular
      #   Whether this element appears at most once (singular) or can repeat (array).
      #   @return [Boolean] true for singular elements, false for repeating elements
      attr_accessor :singular
      alias singular? singular

      # @!attribute [rw] nillable
      #   Whether this element can have a nil value (xsi:nil="true").
      #   This corresponds to the nillable="true" attribute in the XSD schema.
      #   @return [Boolean] true if the element is nillable
      attr_accessor :nillable
      alias nillable? nillable

      # Returns whether this element's type is defined recursively.
      #
      # A recursive type definition means one of this element's ancestors
      # has the same complex type as this element, which would cause
      # infinite recursion if fully expanded.
      #
      # @return [Boolean] true if this element has a recursive type definition
      def recursive?
        !!recursive_type
      end

      # @!attribute [rw] recursive_type
      #   The name of the recursive type definition, if any.
      #   @return [String, nil] the recursive type name
      attr_accessor :recursive_type

      # @!attribute [rw] complex_type_id
      #   The complex type ID for tracking recursive type definitions.
      #   Format is "namespace:localName".
      #   @return [String, nil] the complex type identifier
      # @api private
      attr_accessor :complex_type_id

      # @!attribute [rw] children
      #   The child elements for complex type elements.
      #   @return [Array<Element>] the child elements
      attr_accessor :children

      # @!attribute [rw] any_content
      #   Whether this element allows arbitrary content via xs:any wildcard.
      #   When true, the element can contain any well-formed XML elements
      #   beyond those explicitly defined in the schema.
      #   @return [Boolean] true if arbitrary content is allowed
      attr_accessor :any_content
      alias any_content? any_content

      # @!attribute [rw] attributes
      #   The XML attributes defined on this element.
      #   @return [Array<Attribute>] the attribute definitions
      attr_accessor :attributes

      # Converts this element and its children to an Array representation for inspection.
      #
      # Each element is represented as a tuple of [path, data], where path is an
      # array of element names from the root, and data is a hash containing the
      # element's properties.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @param stack [Array<String>] current path of element names (internal use)
      # @return [Array<Array>] array of [path, data] tuples
      #
      # @example
      #   element.to_a
      #   # => [
      #   #      [["user"], { namespace: "http://example.com", form: "qualified", singular: true }],
      #   #      [["user", "name"], { namespace: nil, form: "unqualified", singular: true, type: "xsd:string" }]
      #   #    ]
      #
      # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity -- straightforward tree traversal, splitting would hurt readability
      def to_a(memo = [], stack = [])
        new_stack = stack + [name]
        data = { namespace: namespace, form: form, singular: singular? }

        unless attributes.empty?
          data[:attributes] = attributes.to_h { |attribute|
            [attribute.name, { optional: attribute.optional? }]
          }
        end

        if recursive?
          data[:recursive_type] = recursive_type
          memo << [new_stack, data]

        elsif simple_type?
          data[:type] = base_type
          memo << [new_stack, data]

        elsif complex_type?
          data[:any_content] = true if any_content?
          memo << [new_stack, data]

          children.each do |child|
            child.to_a(memo, new_stack)
          end

        end

        memo
      end
      # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    end
  end
end
