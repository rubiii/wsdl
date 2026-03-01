# frozen_string_literal: true

require 'wsdl/schema/qname'
require 'wsdl/xml/element'
require 'wsdl/xml/attribute'

class WSDL
  class XML
    # Builds XML Element trees from WSDL message part definitions.
    #
    # Transforms WSDL message parts into a tree of {Element} objects that
    # represent the structure of SOAP messages. Resolves type references,
    # handles complex and simple types, and detects recursive type definitions
    # to prevent infinite loops during element building.
    #
    class ElementBuilder
      include Schema::QName

      # Creates a new ElementBuilder instance.
      #
      # @param schemas [Schema::Collection] the schema collection for resolving types
      def initialize(schemas)
        @logger = Logging.logger[self]
        @schemas = schemas
      end

      # Builds Element trees from WSDL message parts.
      #
      # Each part can reference either a type (via @type attribute) or an
      # element (via @element attribute). Processes each part and returns
      # the corresponding Element objects.
      #
      # @param parts [Array<Hash>] the message parts to build elements from
      # @return [Array<Element>] the built element trees
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

        handle_type(element, type)
        element
      end

      # Builds an Element from a part with an @element attribute.
      #
      # @param part [Hash] the part definition with :element and :namespaces keys
      # @return [Element] the built element
      # @raise [RuntimeError] if the schema cannot be found
      # rubocop:disable Metrics/AbcSize -- linear element construction, splitting would hurt readability
      def build_element(part)
        local, namespace = expand_qname(part[:element], part[:namespaces])
        schema = @schemas.find_by_namespace(namespace)
        raise "Unable to find schema for #{namespace.inspect}" unless schema

        schema_element = schema.elements.fetch(local)
        type = find_type_for_element(schema_element)

        element = Element.new
        element.name = schema_element.name
        element.form = 'qualified'
        element.namespace = namespace
        element.nillable = schema_element.nillable?

        handle_type(element, type)
        element
      end
      # rubocop:enable Metrics/AbcSize

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
      # @return [void]
      def handle_type(element, type)
        case type
        when Schema::Node
          handle_schema_node_type(element, type)
        when String
          element.base_type = type
        end
      end

      # Handles a Schema::Node type based on its kind.
      #
      # @param element [Element] the element to configure
      # @param type [Schema::Node] the schema node
      # @return [void]
      def handle_schema_node_type(element, type)
        case type.kind
        when :complexType
          element.complex_type_id = type.type_id
          children_and_wildcards = child_elements(element, type)
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
        type.attributes.filter_map { |schema_attr|
          attr = Attribute.new

          if schema_attr.ref
            local, namespace = expand_qname(schema_attr.ref, schema_attr.namespaces)
            schema = find_schema(namespace)

            if schema
              schema_attr = schema.attributes[local]
            else
              @logger.debug("Unable to find schema for attribute@ref #{schema_attr.ref.inspect}")
              next
            end
          end

          attr_type = find_type_for_element(schema_attr)
          handle_simple_type(attr, attr_type)

          attr.name = schema_attr.name
          attr.use = schema_attr.use

          attr
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
      # @return [Hash] a hash with :elements (Array<Element>) and :has_any (Boolean)
      # rubocop:disable Metrics/AbcSize -- cohesive element-building logic, splitting would hurt readability
      def child_elements(parent, type)
        has_any = false
        elements = []

        type.elements.each do |child_element|
          if child_element.kind == :any
            has_any = true
            next
          end

          el = Element.new
          el.parent = parent

          max_occurs = child_element['maxOccurs'].to_s
          el.singular = max_occurs.empty? || max_occurs == '1'

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
            handle_type(el, child_type)
          end

          elements << el
        end

        { elements: elements, has_any: has_any }
      end
      # rubocop:enable Metrics/AbcSize

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

        local, namespace = expand_qname(element.type, element.namespaces)
        id = "#{namespace}:#{local}"

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
        local, namespace = expand_qname(qname, namespaces)

        return qname unless namespace

        schema = find_schema(namespace)

        if schema
          schema.complex_types[local] || schema.simple_types[local]
        else
          qname
        end
      end

      # Finds a global element by its qualified name.
      #
      # @param qname [String] the qualified element name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node] the resolved element
      def find_element(qname, namespaces)
        local, namespace = expand_qname(qname, namespaces)
        @schemas.find_element(namespace, local)
      end

      # Finds a global attribute by its qualified name.
      #
      # @param qname [String] the qualified attribute name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node] the resolved attribute
      def find_attribute(qname, namespaces)
        local, namespace = expand_qname(qname, namespaces)
        @schemas.find_attribute(namespace, local)
      end

      # Finds a schema by its target namespace.
      #
      # @param namespace [String] the namespace URI
      # @return [Schema::Definition, nil] the matching schema, or nil if not found
      def find_schema(namespace)
        @schemas.find_by_namespace(namespace)
      end
    end
  end
end
