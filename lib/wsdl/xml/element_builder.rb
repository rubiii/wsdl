# frozen_string_literal: true

require 'wsdl/xml/element'
require 'wsdl/xml/attribute'

module WSDL
  module XML
    # Builds XML Element trees from WSDL message part definitions.
    #
    # Transforms WSDL message parts into a tree of {Element} objects that
    # represent the structure of SOAP messages. Resolves type references,
    # handles complex and simple types, and detects recursive type definitions
    # to prevent infinite loops during element building.
    #
    class ElementBuilder
      include Log

      # Creates a new ElementBuilder instance.
      #
      # @param schemas [Schema::Collection] the schema collection for resolving types
      # @param limits [Limits, nil] resource limits for DoS protection.
      #   If nil, uses {WSDL.limits}.
      def initialize(schemas, limits: nil)
        @schemas = schemas
        @limits = limits || WSDL.limits
      end

      # Builds Element trees from WSDL message parts.
      #
      # Each part can reference either a type (via @type attribute) or an
      # element (via @element attribute). Processes each part and returns
      # the corresponding Element objects.
      #
      # @param parts [Array<Hash>] the message parts to build elements from
      # @return [Array<Element>] the built element trees
      # @raise [ResourceLimitError] if type nesting depth exceeds limits
      def build(parts)
        parts.filter_map { |part|
          if part[:type]
            build_type_element(part)
          elsif part[:element]
            build_element(part)
          end
        }
      end

      private

      # Builds an Element from a part with a @type attribute.
      #
      # @param part [Hash] the part definition with :type, :name, and :namespaces keys
      # @return [Element] the built element
      def build_type_element(part)
        type = find_type(part[:type], part[:namespaces])

        element = Element.new
        element.name = part[:name]
        element.form = 'unqualified'
        element.min_occurs = '1'
        element.max_occurs = '1'

        handle_type(element, type)
        element.freeze
      end

      # Builds an Element from a part with an @element attribute.
      #
      # @param part [Hash] the part definition with :element and :namespaces keys
      # @return [Element] the built element
      # @raise [UnresolvedReferenceError] if element references cannot be resolved
      def build_element(part)
        schema_element, namespace = resolve_part_schema_element(part)
        type = find_type_for_element(schema_element)
        element = instantiate_schema_element(schema_element, namespace)

        handle_type(element, type)
        element.freeze
      end

      def resolve_part_schema_element(part)
        resolved = QName.parse(part[:element], namespaces: part[:namespaces])
        schema_element = @schemas.fetch_element(
          resolved.namespace,
          resolved.local,
          context: "message part element reference #{part[:element].inspect}"
        )

        [schema_element, resolved.namespace]
      end

      def instantiate_schema_element(schema_element, namespace)
        element = Element.new
        element.name = schema_element.name
        element.form = 'qualified'
        element.namespace = namespace
        element.nillable = schema_element.nillable?
        element.min_occurs = schema_element.min_occurs
        element.max_occurs = schema_element.max_occurs
        element
      end

      # Applies type information to an element.
      #
      # Handles four cases:
      # - Complex type node: Sets up child elements and attributes
      # - Simple type node: Sets the base type from the restriction
      # - String: Sets the base type directly (built-in type)
      # - nil: Element may have any content
      #
      # @param element [Element] the element to configure
      # @param type [Schema::Node, String, nil] the type information
      # @param depth [Integer] the current nesting depth (default: 1)
      # @return [void]
      def handle_type(element, type, depth: 1)
        case type
        when Schema::Node
          handle_schema_node_type(element, type, depth:)
        when String
          element.base_type = type
        end
      end

      # Handles a Schema::Node type based on its kind.
      #
      # @param element [Element] the element to configure
      # @param type [Schema::Node] the schema node
      # @param depth [Integer] the current nesting depth
      # @return [void]
      def handle_schema_node_type(element, type, depth: 1)
        case type.kind
        when :complexType
          element.complex_type_id = type.type_id
          children_and_wildcards = child_elements(element, type, depth:)
          element.children = children_and_wildcards[:elements]
          element.any_content = children_and_wildcards[:has_any]
          element.attributes = element_attributes(type)
        when :simpleType
          element.base_type = type.restriction_base
        end
      end

      # Applies type information to an attribute.
      #
      # @param attribute [Attribute] the attribute to configure
      # @param type [Schema::Node, String] the type information
      # @return [void]
      def handle_simple_type(attribute, type)
        case type
        when Schema::Node
          attribute.base_type = type.restriction_base if type.kind == :simpleType
        when String
          attribute.base_type = type
        end
      end

      # Builds Attribute objects from a complex type's attribute definitions.
      #
      # @param type [Schema::Node] the complex type to extract attributes from
      # @return [Array<Attribute>] the built attribute objects
      # rubocop:disable Metrics/AbcSize -- linear attribute construction logic
      def element_attributes(type)
        type.attributes([], limits: @limits).filter_map { |schema_attr|
          attr = Attribute.new

          if schema_attr.ref
            begin
              schema_attr = find_attribute(
                schema_attr.ref,
                schema_attr.namespaces,
                context: "attribute@ref #{schema_attr.ref.inspect} on type #{type.name.inspect}"
              )
            rescue UnresolvedReferenceError => e
              logger.debug("Unable to resolve attribute@ref #{schema_attr.ref.inspect}: #{e.message}")
              next
            end
          end

          attr_type = find_type_for_element(schema_attr)
          handle_simple_type(attr, attr_type)

          attr.name = schema_attr.name
          attr.use = schema_attr.use

          attr.freeze
        }
      end
      # rubocop:enable Metrics/AbcSize

      # Builds child Element objects from a complex type's element definitions.
      #
      # Processes each child element in the type, resolving references and
      # types. Detects recursive type definitions to prevent infinite loops.
      # Also detects xs:any wildcards to mark elements allowing arbitrary content.
      #
      # @param parent [Element] the parent element
      # @param type [Schema::Node] the complex type to extract children from
      # @param depth [Integer] the current nesting depth (default: 1)
      # @return [Hash] a hash with :elements (Array<Element>) and :has_any (Boolean)
      # @raise [ResourceLimitError] if nesting depth exceeds max_type_nesting_depth
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength -- cohesive element-building logic
      def child_elements(parent, type, depth: 1)
        validate_nesting_depth!(depth, type)
        has_any = false
        elements = []

        type.elements([], limits: @limits).each do |child_element|
          if child_element.kind == :any
            has_any = true
            next
          end

          el = Element.new
          el.parent = parent

          max_occurs = child_element['maxOccurs'].to_s
          el.singular = max_occurs.empty? || max_occurs == '1'
          el.min_occurs = child_element.min_occurs
          el.max_occurs = child_element.max_occurs

          if child_element.ref
            child_element = find_element(child_element.ref, child_element.namespaces)
            el.form = 'qualified'
          else
            el.form = child_element.form
          end

          el.name = child_element.name
          el.namespace = child_element.namespace
          el.nillable = child_element.nillable?

          if recursive_child_definition?(parent, child_element)
            el.recursive_type = child_element.type
          else
            child_type = find_type_for_element(child_element)
            handle_type(el, child_type, depth: depth + 1)
          end

          elements << el.freeze
        end

        { elements: elements, has_any: has_any }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength

      # Checks if an element's type creates a recursive definition.
      #
      # Walks up the parent chain to see if any ancestor element has the
      # same complex type ID. If so, the definition is recursive and
      # should not be expanded further.
      #
      # @param parent [Element] the parent element to start checking from
      # @param element [Schema::Node] the element to check for recursion
      # @return [Boolean] true if the element creates a recursive definition
      def recursive_child_definition?(parent, element)
        return false unless element.type

        resolved = QName.parse(element.type, namespaces: element.namespaces)
        id = "#{resolved.namespace}:#{resolved.local}"

        current_parent = parent

        while current_parent
          return true if current_parent.complex_type_id == id

          current_parent = current_parent.parent
        end

        false
      end

      # Finds the type for an element definition.
      #
      # If the element has a @type attribute, resolves it. Otherwise,
      # returns the inline type definition.
      #
      # @param element [Schema::Node] the element to find the type for
      # @return [Schema::Node, String, nil] the resolved type
      def find_type_for_element(element)
        if element.type
          find_type(element.type, element.namespaces)
        else
          element.inline_type
        end
      end

      # Finds and resolves a type by its qualified name.
      #
      # Handles three cases:
      # - Built-in XSD types (returns the qname string)
      # - Custom complex types (returns the Node)
      # - Custom simple types (returns the Node)
      #
      # @param qname [String] the qualified type name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node, String] the resolved type
      def find_type(qname, namespaces)
        resolved = QName.parse(qname, namespaces: namespaces)

        return qname unless resolved.namespace
        return qname if resolved.namespace == NS::XSD

        @schemas.fetch_type(resolved.namespace, resolved.local, context: "type reference #{qname.inspect}")
      end

      # Finds a global element by its qualified name.
      #
      # @param qname [String] the qualified element name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @param context [String, nil] additional context for lookup failures
      # @return [Schema::Node] the resolved element
      def find_element(qname, namespaces, context: nil)
        resolved = QName.parse(qname, namespaces: namespaces)
        @schemas.fetch_element(resolved.namespace, resolved.local,
                               context: context || "element reference #{qname.inspect}")
      end

      # Finds a global attribute by its qualified name.
      #
      # @param qname [String] the qualified attribute name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @param context [String, nil] additional context for lookup failures
      # @return [Schema::Node] the resolved attribute
      def find_attribute(qname, namespaces, context: nil)
        resolved = QName.parse(qname, namespaces: namespaces)
        @schemas.fetch_attribute(resolved.namespace, resolved.local,
                                 context: context || "attribute reference #{qname.inspect}")
      end

      # Validates nesting depth against limits.
      #
      # @param depth [Integer] the current nesting depth
      # @param type [Schema::Node] the type being processed (for error messages)
      # @raise [ResourceLimitError] if depth exceeds max_type_nesting_depth
      def validate_nesting_depth!(depth, type)
        return unless @limits.max_type_nesting_depth
        return if depth <= @limits.max_type_nesting_depth

        raise ResourceLimitError.new(
          "Type nesting depth #{depth} exceeds limit of #{@limits.max_type_nesting_depth} " \
          "while processing type #{type.name.inspect}. This may indicate a recursive type definition " \
          'or an unusually deep type hierarchy.',
          limit_name: :max_type_nesting_depth,
          limit_value: @limits.max_type_nesting_depth,
          actual_value: depth
        )
      end
    end
  end
end
