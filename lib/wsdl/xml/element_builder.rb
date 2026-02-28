# frozen_string_literal: true

require 'wsdl/xml/element'
require 'wsdl/xml/attribute'

class WSDL
  class XML
    # Builds XML Element trees from WSDL message part definitions.
    #
    # This class is responsible for transforming WSDL message parts into
    # a tree of {Element} objects that represent the structure of SOAP
    # messages. It resolves type references, handles complex and simple
    # types, and detects recursive type definitions to prevent infinite
    # loops during element building.
    #
    # @api private
    #
    # rubocop:disable Metrics/ClassLength -- cohesive builder class, splitting would create artificial boundaries
    class ElementBuilder
      # Creates a new ElementBuilder instance.
      #
      # @param schemas [XS::SchemaCollection] the schema collection for resolving types
      def initialize(schemas)
        @logger = Logging.logger[self]
        @schemas = schemas
      end

      # Builds Element trees from WSDL message parts.
      #
      # Each part can reference either a type (via @type attribute) or an
      # element (via @element attribute). This method processes each part
      # and returns the corresponding Element objects.
      #
      # @param parts [Array<Hash>] the message parts to build elements from
      # @return [Array<Element>] the built element trees
      def build(parts)
        parts.map { |part|
          if part[:type]
            build_type_element(part)
          elsif part[:element]
            build_element(part)
          end
        }.compact
      end

      private

      # Builds an Element from a part with a @type attribute.
      #
      # Resolves the type reference and creates an Element with that type.
      # The element is unqualified since it's defined by type rather than
      # a global element declaration.
      #
      # @param part [Hash] the part definition with :type, :name, and :namespaces keys
      # @return [Element] the built element
      def build_type_element(part)
        type = find_type part[:type], part[:namespaces]

        element = Element.new
        element.name = part[:name]
        element.form = 'unqualified'

        handle_type(element, type)
        element
      end

      # Builds an Element from a part with an @element attribute.
      #
      # Resolves the element reference from the schema, then resolves its
      # type. The element is qualified since it references a global element
      # declaration.
      #
      # @param part [Hash] the part definition with :element and :namespaces keys
      # @return [Element] the built element
      # @raise [RuntimeError] if the schema cannot be found
      def build_element(part)
        local, namespace = expand_qname(part[:element], part[:namespaces])
        schema = @schemas.find_by_namespace(namespace)
        raise "Unable to find schema for #{namespace.inspect}" unless schema

        xs_element = schema.elements.fetch(local)
        type = find_type_for_element(xs_element)

        element = Element.new
        element.name = xs_element.name
        element.form = 'qualified'
        element.namespace = namespace

        handle_type(element, type)
        element
      end

      # Applies type information to an element.
      #
      # Handles three cases:
      # - ComplexType: Sets up child elements and attributes
      # - SimpleType: Sets the base type from the restriction
      # - String: Sets the base type directly (built-in type)
      #
      # @param element [Element] the element to configure
      # @param type [XS::ComplexType, XS::SimpleType, String] the type information
      # @return [void]
      def handle_type(element, type)
        case type

        when XS::ComplexType
          element.complex_type_id = type.id
          element.children = child_elements(element, type)
          element.attributes = element_attributes(type)

        when XS::SimpleType
          element.base_type = type.base

        when String
          element.base_type = type

        end
      end

      # Applies type information to an attribute.
      #
      # @param attribute [Attribute] the attribute to configure
      # @param type [XS::SimpleType, String] the type information
      # @return [void]
      def handle_simple_type(attribute, type)
        case type
        when XS::SimpleType then attribute.base_type = type.base
        when String         then attribute.base_type = type
        end
      end

      # Builds Attribute objects from a complex type's attribute definitions.
      #
      # Handles both direct attributes and attribute references (@ref).
      # Referenced attributes are resolved from the schema collection.
      #
      # @param type [XS::ComplexType] the complex type to extract attributes from
      # @return [Array<Attribute>] the built attribute objects
      # rubocop:disable Metrics/AbcSize -- clear linear logic for building attributes
      def element_attributes(type)
        type.attributes.map { |attribute|
          attr = Attribute.new

          if attribute.ref
            local, namespace = expand_qname(attribute.ref, attribute.namespaces)
            schema = find_schema(namespace)

            if schema
              attribute = schema.attributes[local]
            else
              @logger.debug("Unable to find schema for attribute@ref #{attribute.ref.inspect}")
              next
            end
          end

          type = find_type_for_attribute(attribute)
          handle_simple_type(attr, type)

          attr.name = attribute.name
          attr.use = attribute.use

          attr
        }.compact
      end
      # rubocop:enable Metrics/AbcSize

      # Builds child Element objects from a complex type's element definitions.
      #
      # Processes each child element in the type, resolving references and
      # types. Detects recursive type definitions to prevent infinite loops.
      #
      # @param parent [Element] the parent element
      # @param type [XS::ComplexType] the complex type to extract children from
      # @return [Array<Element>] the built child elements
      # rubocop:disable Metrics/AbcSize -- cohesive element-building logic, splitting would hurt readability
      def child_elements(parent, type)
        type.elements.map do |child_element|
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

          # prevent recursion
          if recursive_child_definition? parent, child_element
            el.recursive_type = child_element.type
          else
            type = find_type_for_element(child_element)
            handle_type(el, type)
          end

          el
        end
      end
      # rubocop:enable Metrics/AbcSize

      # Checks if an element's type creates a recursive definition.
      #
      # Walks up the parent chain to see if any ancestor element has the
      # same complex type ID as this element. If so, the definition is
      # recursive and should not be expanded further.
      #
      # @param parent [Element] the parent element to start checking from
      # @param element [XS::Element] the element to check for recursion
      # @return [Boolean] true if the element creates a recursive definition
      def recursive_child_definition?(parent, element)
        return false unless element.type

        local, namespace = expand_qname(element.type, element.namespaces)
        id = [namespace, local].join(':')

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
      # @param element [XS::Element] the element to find the type for
      # @return [XS::ComplexType, XS::SimpleType, String, nil] the resolved type
      def find_type_for_element(element)
        if element.type
          find_type(element.type, element.namespaces)
        else
          element.inline_type
        end
      end

      alias find_type_for_attribute find_type_for_element

      # Finds and resolves a type by its qualified name.
      #
      # Handles three cases:
      # - Built-in XSD types (returns the qname string)
      # - Custom complex types (returns the ComplexType object)
      # - Custom simple types (returns the SimpleType object)
      #
      # @param qname [String] the qualified type name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [XS::ComplexType, XS::SimpleType, String] the resolved type
      def find_type(qname, namespaces)
        local, namespace = expand_qname(qname, namespaces)

        # assume built-in or unknown type for unqualified type qnames for now.
        # we could fallback to the element's default namespace. needs tests.
        return qname unless namespace

        schema = find_schema(namespace)

        # custom type
        if schema

          # complex type
          if (complex_type = schema.complex_types[local])
            complex_type

          # simple type
          elsif (simple_type = schema.simple_types[local])
            simple_type

          end

        # built-in or unknown type
        else
          qname

        end
      end

      # Finds a global element by its qualified name.
      #
      # @param qname [String] the qualified element name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [XS::Element] the resolved element
      def find_element(qname, namespaces)
        local, namespace = expand_qname(qname, namespaces)
        @schemas.element(namespace, local)
      end

      # Finds a global attribute by its qualified name.
      #
      # @param qname [String] the qualified attribute name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [XS::Attribute] the resolved attribute
      def find_attribute(qname, namespaces)
        local, namespace = expand_qname(qname, namespaces)
        @schemas.attribute(namespace, local)
      end

      # Finds a schema by its target namespace.
      #
      # @param namespace [String] the namespace URI
      # @return [XS::Schema, nil] the matching schema, or nil if not found
      def find_schema(namespace)
        @schemas.find_by_namespace(namespace)
      end

      # Splits a qualified name into local name and prefix.
      #
      # @param qname [String] the qualified name (prefix:localName or just localName)
      # @return [Array<String>] a tuple of [localName, prefix]
      def split_qname(qname)
        qname.split(':').reverse
      end

      # Expands a qualified name to local name and namespace URI.
      #
      # @param qname [String] the qualified name (prefix:localName)
      # @param namespaces [Hash] namespace declarations (xmlns:prefix => URI)
      # @return [Array<String, String>] a tuple of [localName, namespaceURI]
      def expand_qname(qname, namespaces)
        local, nsid = split_qname(qname)
        namespace = namespaces["xmlns:#{nsid}"]

        [local, namespace]
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
