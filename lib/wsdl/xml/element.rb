# frozen_string_literal: true

module WSDL
  # Namespace for XML-related classes used in SOAP message construction.
  #
  # This module contains classes for representing XML elements and attributes
  # that are used to build SOAP request messages based on WSDL definitions.
  #
  # @api private
  #
  module XML
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
      # Canonical frozen empty array shared for elements without children.
      #
      # @return [Array<Element>]
      EMPTY_CHILDREN = [].freeze

      # Canonical frozen empty array shared for elements without attributes.
      #
      # @return [Array<WSDL::XML::Attribute>]
      EMPTY_ATTRIBUTES = [].freeze

      # Creates a new Element with default values.
      def initialize
        @children    = EMPTY_CHILDREN
        @attributes  = EMPTY_ATTRIBUTES
        @recursive   = false
        @singular    = true
        @min_occurs  = '1'
        @max_occurs  = '1'
        @any_content = false
        @nillable    = false
        @list        = false
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

      # Returns the kind of this element.
      #
      # Provides a three-way classification for introspection.
      # Note: recursive elements are a subset of complex types.
      # Use {#simple_type?} and {#complex_type?} for binary dispatch.
      #
      # @return [Symbol] :recursive, :simple, or :complex
      def kind
        if recursive?
          :recursive
        elsif base_type
          :simple
        else
          :complex
        end
      end

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
      # Recursive elements are also considered complex types.
      #
      # @return [Boolean] true if this is a complex type element
      def complex_type?
        !simple_type?
      end

      # @!attribute [rw] base_type
      #   The base type name for simple type elements (e.g., 'xsd:string').
      #   @return [String, nil] the base type name, or nil for complex types
      attr_accessor :base_type

      # @!attribute [rw] list
      #   Whether this element is an xs:list type (whitespace-separated values).
      #   @return [Boolean] true for list-derived simple types
      attr_accessor :list
      alias list? list

      # @!attribute [rw] singular
      #   Whether this element appears at most once (singular) or can repeat (array).
      #   @return [Boolean] true for singular elements, false for repeating elements
      attr_accessor :singular
      alias singular? singular

      # @!attribute [rw] min_occurs
      #   Minimum occurrences for this element in schema terms.
      #   @return [String] minOccurs value (default: '1')
      attr_accessor :min_occurs

      # @!attribute [rw] max_occurs
      #   Maximum occurrences for this element in schema terms.
      #   @return [String] maxOccurs value (default: '1')
      attr_accessor :max_occurs

      # @return [Boolean] true if the element is optional (minOccurs=0)
      def optional?
        min_occurs.to_s == '0'
      end

      # @return [Boolean] true if the element is required (minOccurs>0)
      def required?
        !optional?
      end

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

      # The XML attributes defined on this element.
      #
      # @return [Array<Attribute>] the attribute definitions
      attr_reader :attributes

      # Sets attribute definitions for this element.
      #
      # @param value [Array<Attribute>, nil] attribute definitions
      # @raise [TypeError] if value is not an array of {Attribute}
      # @return [void]
      def attributes=(value)
        normalized = value.nil? ? EMPTY_ATTRIBUTES : value

        unless normalized.is_a?(Array) && normalized.all?(Attribute)
          raise TypeError, "attributes must be an Array<WSDL::XML::Attribute>, got #{value.class}"
        end

        @attributes = normalized.empty? ? EMPTY_ATTRIBUTES : normalized.dup.freeze
      end

      # Deep-freezes this element by also freezing the mutable +@children+ array.
      #
      # The +@attributes+ array is already frozen by the custom setter,
      # so only +@children+ needs explicit freezing here.
      #
      # @return [self]
      def freeze
        @children.freeze
        super
      end

      # Returns a definition-oriented hash representation of the element tree.
      #
      # Converts this element and all children/attributes into plain hashes
      # suitable for storage in a {Definition}. The format preserves all
      # schema properties needed by consumers (Response::Parser,
      # Response::Builder, Request::Validator) and can be round-tripped
      # through serialization.
      #
      # @return [Hash{Symbol => Object}] definition-compatible element hash
      #
      # @example
      #   element.to_definition_h
      #   # => { name: "user", namespace: "http://example.com", form: "qualified",
      #   #      type: "complex", xsd_type: nil, min_occurs: 1, max_occurs: 1,
      #   #      nillable: false, singular: true, list: false, any_content: false,
      #   #      recursive_type: nil, complex_type_id: nil,
      #   #      children: [...], attributes: [...] }
      #
      def to_definition_h # rubocop:disable Metrics/AbcSize
        {
          name:,
          namespace:,
          form:,
          type: kind.to_s.freeze,
          xsd_type: base_type,
          min_occurs: min_occurs.to_i,
          max_occurs: definition_max_occurs,
          nillable: nillable?,
          singular: singular?,
          list: list?,
          any_content: any_content?,
          recursive_type:,
          complex_type_id:,
          children: children.map(&:to_definition_h).freeze,
          attributes: attributes.map(&:to_definition_h).freeze
        }.freeze
      end

      # Compares two elements by their properties (excluding parent reference).
      #
      # Performs deep comparison including children and attributes.
      #
      # @param other [Object] the object to compare
      # @return [Boolean] true if elements have identical properties
      #
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- all fields compared
      def ==(other)
        return false unless other.is_a?(self.class)

        name == other.name &&
          namespace == other.namespace &&
          form == other.form &&
          base_type == other.base_type &&
          min_occurs == other.min_occurs &&
          max_occurs == other.max_occurs &&
          singular == other.singular &&
          nillable == other.nillable &&
          list == other.list &&
          any_content == other.any_content &&
          recursive_type == other.recursive_type &&
          complex_type_id == other.complex_type_id &&
          children == other.children &&
          attributes == other.attributes
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      alias eql? ==

      # @return [Integer] hash code based on element properties (excluding parent)
      def hash
        [
          name, namespace, form, base_type, min_occurs, max_occurs,
          singular, nillable, list, any_content, recursive_type, complex_type_id,
          children, attributes
        ].hash
      end

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
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity -- straightforward tree traversal with kind dispatch
      def to_a(memo = [], stack = [])
        new_stack = stack + [name]
        data = {
          namespace:,
          form:,
          singular: singular?,
          min_occurs:,
          max_occurs:
        }

        data[:kind] = kind
        data[:attributes] = attributes.map(&:to_h) unless attributes.empty?

        case kind
        when :recursive
          data[:recursive_type] = recursive_type
        when :simple
          data[:type] = base_type
          data[:list] = list?
        when :complex
          data[:any_content] = any_content?
        end

        memo << [new_stack, data]
        children.each { |child| child.to_a(memo, new_stack) } if kind == :complex

        memo
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

      private

      # @return [Integer, Float] max_occurs as a numeric value for definition hashes
      def definition_max_occurs
        max_occurs == 'unbounded' ? Float::INFINITY : max_occurs.to_i
      end
    end
  end
end
