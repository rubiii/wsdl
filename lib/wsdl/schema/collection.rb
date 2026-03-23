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
      def find_element(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.elements[name]
      end

      # Fetches a global element by namespace and name.
      #
      # Unlike {#find_element}, this raises when the element itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the element
      # @param context [String, nil] additional context for error messages
      # @return [Node] the element node
      # @raise [UnresolvedReferenceError] if schema or element cannot be resolved
      def fetch_element(namespace, name, context: nil)
        definition = fetch_schema_definition!(:element, namespace, name, context:)
        element = definition.elements[name]
        return element if element

        raise_missing_component!(component: :element, namespace:, name:, available_components: definition.elements.keys,
                                 context:)
      end

      # Finds a complex type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the complex type node, or nil if not found
      def find_complex_type(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.complex_types[name]
      end

      # Fetches a complex type by namespace and name.
      #
      # Unlike {#find_complex_type}, this raises when the type itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @param context [String, nil] additional context for error messages
      # @return [Node] the complex type node
      # @raise [UnresolvedReferenceError] if schema or type cannot be resolved
      def fetch_complex_type(namespace, name, context: nil)
        definition = fetch_schema_definition!(:complex_type, namespace, name, context:)
        type = definition.complex_types[name]
        return type if type

        raise_missing_component!(component: :complex_type, namespace:, name:,
                                 available_components: definition.complex_types.keys, context:)
      end

      # Finds a simple type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the simple type node, or nil if not found
      def find_simple_type(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.simple_types[name]
      end

      # Fetches a simple type by namespace and name.
      #
      # Unlike {#find_simple_type}, this raises when the type itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @param context [String, nil] additional context for error messages
      # @return [Node] the simple type node
      # @raise [UnresolvedReferenceError] if schema or type cannot be resolved
      def fetch_simple_type(namespace, name, context: nil)
        definition = fetch_schema_definition!(:simple_type, namespace, name, context:)
        type = definition.simple_types[name]
        return type if type

        raise_missing_component!(
          component: :simple_type,
          namespace:,
          name:,
          available_components: definition.simple_types.keys,
          context:
        )
      end

      # Finds a type (complex or simple) by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @return [Node, nil] the type node, or nil if not found
      def find_type(namespace, name)
        find_complex_type(namespace, name) || find_simple_type(namespace, name)
      end

      # Fetches a type (complex or simple) by namespace and name.
      #
      # Unlike {#find_type}, this raises when the type itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the type
      # @param context [String, nil] additional context for error messages
      # @return [Node] the type node
      # @raise [UnresolvedReferenceError] if schema or type cannot be resolved
      def fetch_type(namespace, name, context: nil)
        definition = fetch_schema_definition!(:type, namespace, name, context:)
        type = definition.complex_types[name] || definition.simple_types[name]
        return type if type

        available = (definition.complex_types.keys + definition.simple_types.keys).uniq
        raise_missing_component!(component: :type, namespace:, name:, available_components: available, context:)
      end

      # Finds a global attribute by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute
      # @return [Node, nil] the attribute node, or nil if not found
      def find_attribute(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.attributes[name]
      end

      # Fetches a global attribute by namespace and name.
      #
      # Unlike {#find_attribute}, this raises when the attribute itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute
      # @param context [String, nil] additional context for error messages
      # @return [Node] the attribute node
      # @raise [UnresolvedReferenceError] if schema or attribute cannot be resolved
      def fetch_attribute(namespace, name, context: nil)
        definition = fetch_schema_definition!(:attribute, namespace, name, context:)
        attribute = definition.attributes[name]
        return attribute if attribute

        raise_missing_component!(
          component: :attribute,
          namespace:,
          name:,
          available_components: definition.attributes.keys,
          context:
        )
      end

      # Finds a model group by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the group
      # @return [Node, nil] the group node, or nil if not found
      def find_group(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.groups[name]
      end

      # Fetches a model group by namespace and name.
      #
      # Unlike {#find_group}, this raises when the group itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the group
      # @param context [String, nil] additional context for error messages
      # @return [Node] the group node
      # @raise [UnresolvedReferenceError] if schema or group cannot be resolved
      def fetch_group(namespace, name, context: nil)
        definition = fetch_schema_definition!(:group, namespace, name, context:)
        group = definition.groups[name]
        return group if group

        raise_missing_component!(component: :group, namespace:, name:,
                                 available_components: definition.groups.keys, context:)
      end

      # Finds an attribute group by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute group
      # @return [Node, nil] the attribute group node, or nil if not found
      def find_attribute_group(namespace, name)
        definition = find_by_namespace(namespace)
        return nil unless definition

        definition.attribute_groups[name]
      end

      # Fetches an attribute group by namespace and name.
      #
      # Unlike {#find_attribute_group}, this raises when the group itself is missing.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute group
      # @param context [String, nil] additional context for error messages
      # @return [Node] the attribute group node
      # @raise [UnresolvedReferenceError] if schema or attribute group cannot be resolved
      def fetch_attribute_group(namespace, name, context: nil)
        definition = fetch_schema_definition!(:attribute_group, namespace, name, context:)
        group = definition.attribute_groups[name]
        return group if group

        raise_missing_component!(component: :attribute_group, namespace:, name:,
                                 available_components: definition.attribute_groups.keys, context:)
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

      # Raises a typed error when a schema namespace cannot be found.
      #
      # @param component [Symbol] component type being looked up
      # @param namespace [String, nil] the namespace that wasn't found
      # @param name [String] the local name of the component
      # @param context [String, nil] additional call-site context
      # @raise [UnresolvedReferenceError] always raises with a descriptive message
      def raise_missing_schema_namespace!(component:, namespace:, name:, context: nil)
        available = available_namespaces

        if namespace.nil?
          raise UnresolvedReferenceError.new(
            "Unable to find #{component_name(component)} '#{name}' - no schema found for namespace nil. " \
            'This may indicate an element reference without a namespace prefix in an XSD ' \
            "that doesn't define a default namespace (xmlns=\"...\").",
            reference_type: :schema_namespace,
            reference_name: name,
            namespace: namespace,
            context:
          )
        end

        raise UnresolvedReferenceError.new(
          "Unable to find #{component_name(component)} '#{name}' - " \
          "no schema found for namespace #{namespace.inspect}. " \
          "Available namespaces: #{available.empty? ? '(none)' : available.map(&:inspect).join(', ')}",
          reference_type: :schema_namespace,
          reference_name: name,
          namespace: namespace,
          context:
        )
      end

      # Fetches a schema definition by namespace and raises typed errors if missing.
      #
      # @param component [Symbol] component type being looked up
      # @param namespace [String, nil] schema namespace
      # @param name [String] local component name
      # @param context [String, nil] additional call-site context
      # @return [Definition] matching schema definition
      # @raise [UnresolvedReferenceError] when namespace does not exist
      def fetch_schema_definition!(component, namespace, name, context: nil)
        definition = find_by_namespace(namespace)
        return definition if definition

        raise_missing_schema_namespace!(component:, namespace:, name:, context:)
      end

      # Raises a typed error when a component does not exist in a matched schema.
      #
      # @param component [Symbol] component type
      # @param namespace [String, nil] target namespace
      # @param name [String] local component name
      # @param available_components [Array<String>] available names in that schema
      # @param context [String, nil] additional call-site context
      # @raise [UnresolvedReferenceError] always
      def raise_missing_component!(component:, namespace:, name:, available_components:, context: nil)
        available = available_components.sort

        raise UnresolvedReferenceError.new(
          "Unable to find #{component_name(component)} '#{name}' in schema namespace #{namespace.inspect}. " \
          "Available #{component_name(component)}s: #{available.empty? ? '(none)' : available.join(', ')}",
          reference_type: component,
          reference_name: name,
          namespace:,
          context:
        )
      end

      # Returns all known target namespaces in the collection.
      #
      # @return [Array<String>]
      def available_namespaces
        @definitions.filter_map(&:target_namespace)
      end

      # Returns a human-readable name for a component symbol.
      #
      # @param component [Symbol]
      # @return [String]
      def component_name(component)
        case component
        when :complex_type then 'complexType'
        when :simple_type then 'simpleType'
        when :attribute_group then 'attributeGroup'
        else component.to_s
        end
      end
    end
  end
end
