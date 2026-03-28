# frozen_string_literal: true

module WSDL
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

      # Shared empty array returned for unknown namespaces to avoid allocation.
      #
      # @return [Array]
      EMPTY_DEFINITIONS = [].freeze

      # Creates a new empty collection.
      def initialize
        @definitions = []
        @by_namespace = {}
      end

      # Adds a definition to the collection.
      #
      # @param definition [Definition] the schema definition to add
      # @return [Collection] self for chaining
      def <<(definition)
        @definitions << definition
        (@by_namespace[definition.target_namespace] ||= []) << definition
        self
      end

      # Adds multiple definitions to the collection.
      #
      # @param definitions [Array<Definition>] the definitions to add
      # @return [Collection] self for chaining
      def push(definitions)
        @definitions.concat(definitions)
        definitions.each do |d|
          (@by_namespace[d.target_namespace] ||= []) << d
        end
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

      # Releases all references to the Nokogiri DOM from every definition
      # in the collection.
      #
      # Called by {Parser.parse} after the Definition IR is built so the GC
      # can reclaim the DOM trees while the collection is still reachable.
      #
      # @return [void]
      def release_dom_references!
        @definitions.each(&:release_dom_references!)
      end

      # @!group Lookups

      # Finds a global element by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the element
      # @return [Node, nil] the element node, or nil if not found
      def find_element(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          element = definition.elements[name]
          return element if element
        end
        nil
      end

      # Finds a complex type by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the complex type node, or nil if not found
      def find_complex_type(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          type = definition.complex_types[name]
          return type if type
        end
        nil
      end

      # Finds a simple type by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the simple type node, or nil if not found
      def find_simple_type(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          type = definition.simple_types[name]
          return type if type
        end
        nil
      end

      # Finds a type (complex or simple) by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      # Complex and simple types share a symbol space within a namespace,
      # so both are checked per definition before moving to the next.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the type node, or nil if not found
      def find_type(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          type = definition.complex_types[name] || definition.simple_types[name]
          return type if type
        end
        nil
      end

      # Finds a global attribute by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute
      # @return [Node, nil] the attribute node, or nil if not found
      def find_attribute(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          attribute = definition.attributes[name]
          return attribute if attribute
        end
        nil
      end

      # Finds a model group by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the group
      # @return [Node, nil] the group node, or nil if not found
      def find_group(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          group = definition.groups[name]
          return group if group
        end
        nil
      end

      # Finds an attribute group by namespace and name.
      #
      # Searches all definitions sharing the namespace per XSD §4.2.3.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute group
      # @return [Node, nil] the attribute group node, or nil if not found
      def find_attribute_group(namespace, name)
        definitions_for_namespace(namespace).each do |definition|
          group = definition.attribute_groups[name]
          return group if group
        end
        nil
      end

      # Finds the first definition matching a target namespace.
      #
      # @param namespace [String, nil] the target namespace URI
      # @return [Definition, nil] the first matching definition, or nil if not found
      def find_by_namespace(namespace)
        definitions_for_namespace(namespace).first
      end

      # @!endgroup

      private

      # Returns all definitions for a given namespace.
      #
      # @param namespace [String, nil] the target namespace URI
      # @return [Array<Definition>] matching definitions (empty if none)
      def definitions_for_namespace(namespace)
        @by_namespace.fetch(namespace, EMPTY_DEFINITIONS)
      end
    end
  end
end
