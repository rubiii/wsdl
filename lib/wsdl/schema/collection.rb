# frozen_string_literal: true

class WSDL
  module Schema
    # A collection of XML Schema definitions with lookup capabilities.
    #
    # Aggregates multiple {Definition} instances and provides unified lookup
    # methods for finding schema components (elements, types, attributes)
    # by namespace and local name.
    #
    # @example
    #   collection = Schema::Collection.new
    #   collection << Schema::Definition.new(schema_node, collection)
    #   collection.find_element('http://example.com', 'User')
    #
    class Collection
      include Enumerable

      # Creates a new empty collection.
      def initialize
        @definitions = []
      end

      # Adds a definition to the collection.
      #
      # @param definition [Definition] the schema definition to add
      # @return [Collection] self for chaining
      def <<(definition)
        @definitions << definition
        self
      end

      # Adds multiple definitions to the collection.
      #
      # @param definitions [Array<Definition>] the definitions to add
      # @return [Collection] self for chaining
      def push(definitions)
        @definitions.concat(definitions)
        self
      end

      # Iterates over each definition in the collection.
      #
      # @yield [definition] yields each definition
      # @yieldparam definition [Definition] a schema definition
      # @return [Enumerator, Collection] enumerator if no block given
      def each(&)
        @definitions.each(&)
      end

      # @!group Lookups

      # Finds a global element by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the element
      # @return [Node, nil] the element node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_element(namespace, name)
        definition = find_by_namespace(namespace)
        raise_not_found('element', namespace, name) unless definition

        definition.elements[name]
      end

      # Finds a complex type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the complex type node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_complex_type(namespace, name)
        definition = find_by_namespace(namespace)
        raise_not_found('complexType', namespace, name) unless definition

        definition.complex_types[name]
      end

      # Finds a simple type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the simple type node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_simple_type(namespace, name)
        definition = find_by_namespace(namespace)
        raise_not_found('simpleType', namespace, name) unless definition

        definition.simple_types[name]
      end

      # Finds a type (complex or simple) by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the type node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_type(namespace, name)
        find_complex_type(namespace, name) || find_simple_type(namespace, name)
      end

      # Finds a global attribute by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute
      # @return [Node, nil] the attribute node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_attribute(namespace, name)
        definition = find_by_namespace(namespace)
        raise_not_found('attribute', namespace, name) unless definition

        definition.attributes[name]
      end

      # Finds an attribute group by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute group
      # @return [Node, nil] the attribute group node, or nil if not found
      # @raise [RuntimeError] if no schema matches the namespace
      def find_attribute_group(namespace, name)
        definition = find_by_namespace(namespace)
        raise_not_found('attributeGroup', namespace, name) unless definition

        definition.attribute_groups[name]
      end

      # Finds a definition by its target namespace.
      #
      # @param namespace [String, nil] the target namespace URI
      # @return [Definition, nil] the matching definition, or nil if not found
      def find_by_namespace(namespace)
        find { |definition| definition.target_namespace == namespace }
      end

      # @!endgroup

      private

      # Raises a descriptive error when a schema cannot be found.
      #
      # @param component [String] the component type being looked up
      # @param namespace [String, nil] the namespace that wasn't found
      # @param name [String] the local name of the component
      # @raise [RuntimeError] always raises with a descriptive message
      def raise_not_found(component, namespace, name)
        if namespace.nil?
          raise "Unable to find #{component} '#{name}' - no schema found for namespace nil. " \
                'This may indicate an element reference without a namespace prefix in an XSD ' \
                "that doesn't define a default namespace (xmlns=\"...\")."
        end

        available = @definitions.filter_map(&:target_namespace).map(&:inspect).join(', ')
        raise "Unable to find #{component} '#{name}' - no schema found for namespace #{namespace.inspect}. " \
              "Available namespaces: #{available.empty? ? '(none)' : available}"
      end
    end
  end
end
