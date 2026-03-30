# frozen_string_literal: true

module WSDL
  class Definition
    # Frozen wrapper around a plain element hash that duck-types as {XML::Element}.
    #
    # This allows consumers like {Response::Parser}, {Response::Builder},
    # and {Request::Validator} to work with Definition element data without
    # modification — they call the same methods they would on {XML::Element}.
    #
    # @api private
    #
    class Element
      # @return [Array] shared empty frozen array for absent children/attributes
      EMPTY_ARRAY = [].freeze

      # @param data [Hash{String => Object}] element hash with resolved namespace URI strings
      def initialize(data)
        @data = data

        children = data['children']
        @children = children ? children.map { |c| self.class.new(c) }.freeze : EMPTY_ARRAY

        attributes = data['attributes']
        @attributes = attributes ? attributes.map { |a| Attribute.new(a) }.freeze : EMPTY_ARRAY

        freeze
      end

      # @return [String] local element name
      def name
        @data['name']
      end

      # @return [String, nil] namespace URI
      def namespace
        @data['ns']
      end

      # @return [String] element form ('qualified' or 'unqualified')
      def form
        @data.fetch('form', 'qualified')
      end

      # @return [Symbol] element kind (:simple, :complex, or :recursive)
      def kind
        @data['type'].to_sym
      end

      # @return [String, nil] base type name (e.g. 'xsd:string')
      def base_type
        @data['xsd_type']
      end

      # @return [Boolean] true if this is a simple type element
      def simple_type?
        @data['type'] == 'simple'
      end

      # @return [Boolean] true if this is a complex or recursive type element
      def complex_type?
        %w[complex recursive].include?(@data['type'])
      end

      # @return [Boolean] true if this element appears at most once
      def singular?
        @data.fetch('max', 1) == 1
      end

      # @return [Boolean] true if this is an xs:list type
      def list?
        @data.fetch('list', false)
      end

      # @return [Boolean] true if this element can be nil (xsi:nil="true")
      def nillable?
        @data.fetch('nillable', false)
      end

      # @return [Boolean] true if this element allows xs:any wildcard content
      def any_content?
        @data.fetch('any_content', false)
      end

      # @return [Boolean] true if this element has a recursive type definition
      def recursive?
        @data['type'] == 'recursive'
      end

      # @return [String, nil] the recursive type name
      def recursive_type
        @data['recursive_type']
      end

      # @return [String] minOccurs as a string (for Validator compatibility)
      def min_occurs
        @data.fetch('min', 1).to_s
      end

      # @return [String] maxOccurs as a string ('unbounded' for infinity)
      def max_occurs
        value = @data.fetch('max', 1)
        value == 'unbounded' ? 'unbounded' : value.to_s
      end

      # @return [Boolean] true if the element is optional (minOccurs=0)
      def optional?
        @data.fetch('min', 1).zero?
      end

      # @return [Boolean] true if the element is required (minOccurs>0)
      def required?
        !optional?
      end

      # @return [Array<Element>] child elements
      attr_reader :children

      # @return [Array<Attribute>] attribute definitions
      attr_reader :attributes

      # @return [Hash{String => Object}] the underlying element data
      def to_h
        @data
      end

      # Converts this element and its children to an Array representation.
      #
      # Produces the same format as {XML::Element#to_a} for compatibility
      # with {Contract::PartContract#paths}.
      #
      # @param memo [Array] accumulator for recursive traversal
      # @param stack [Array<String>] current path of element names
      # @return [Array<Array>] array of [path, data] tuples
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity -- mirrors XML::Element#to_a
      def to_a(memo = [], stack = [])
        new_stack = stack + [name]
        data = {
          namespace:, form:, singular: singular?,
          min_occurs:, max_occurs:, kind:
        }
        data[:attributes] = attributes.map(&:to_h) unless attributes.empty?
        case @data['type']
        when 'recursive' then data[:recursive_type] = recursive_type
        when 'simple'
          data[:type] = base_type
          data[:list] = list?
        when 'complex' then data[:any_content] = any_content?
        end
        memo << [new_stack, data]
        children.each { |child| child.to_a(memo, new_stack) } if @data['type'] == 'complex'
        memo
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
    end

    # Frozen wrapper around a plain attribute hash that duck-types as {XML::Attribute}.
    #
    # @api private
    #
    class Attribute
      # @param data [Hash{String => Object}] attribute hash from {XML::Attribute#to_definition_h}
      def initialize(data)
        @data = data
        freeze
      end

      # @return [String] attribute name
      def name
        @data['name']
      end

      # @return [String] base type name (e.g. 'xsd:string')
      def base_type
        @data['base_type']
      end

      # @return [Boolean] true if this is an xs:list type
      def list?
        @data['list']
      end

      # @return [String] use constraint ('optional' or 'required')
      def use
        @data['use']
      end

      # @return [Boolean] true if the attribute is optional
      def optional?
        @data['use'] == 'optional'
      end

      # Returns an introspection-compatible hash matching {XML::Attribute#to_h}.
      #
      # @return [Hash{Symbol => Object}] attribute metadata
      def to_h
        { name:, type: base_type, required: !optional?, list: list? }
      end

      # @return [Hash{String => Object}] the underlying definition data
      def to_definition_h
        @data
      end
    end
  end
end
