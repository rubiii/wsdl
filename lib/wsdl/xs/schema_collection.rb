# frozen_string_literal: true

class WSDL
  class XS
    # A collection of XML Schema definitions.
    #
    # This class aggregates multiple XML Schema documents that may be imported
    # from WSDL documents or other schemas. It provides unified lookup methods
    # for finding schema components (elements, types, attributes) by namespace
    # and local name.
    #
    # @api private
    #
    class SchemaCollection
      include Enumerable

      # Creates a new empty SchemaCollection.
      def initialize
        @schemas = []
      end

      # Adds a schema to the collection.
      #
      # @param schema [Schema] the schema to add
      # @return [Array<Schema>] the updated schemas array
      def <<(schema)
        @schemas << schema
      end

      # Adds multiple schemas to the collection.
      #
      # @param schemas [Array<Schema>] the schemas to add
      # @return [Array<Schema>] the updated schemas array
      def push(schemas)
        @schemas += schemas
      end

      # Iterates over each schema in the collection.
      #
      # @yield [schema] yields each schema
      # @yieldparam schema [Schema] a schema in the collection
      # @return [Enumerator, Array] an enumerator if no block given, otherwise the schemas array
      def each(&)
        @schemas.each(&)
      end

      # Finds a global attribute by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute
      # @return [Attribute, nil] the attribute, or nil if not found
      def attribute(namespace, name)
        find_by_namespace(namespace).attributes[name]
      end

      # Finds an attribute group by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the attribute group
      # @return [AttributeGroup, nil] the attribute group, or nil if not found
      def attribute_group(namespace, name)
        find_by_namespace(namespace).attribute_groups[name]
      end

      # Finds a global element by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the element
      # @return [Element, nil] the element, or nil if not found
      def element(namespace, name)
        find_by_namespace(namespace).elements[name]
      end

      # Finds a complex type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the complex type
      # @return [ComplexType, nil] the complex type, or nil if not found
      def complex_type(namespace, name)
        find_by_namespace(namespace).complex_types[name]
      end

      # Finds a simple type by namespace and name.
      #
      # @param namespace [String] the target namespace URI
      # @param name [String] the local name of the simple type
      # @return [SimpleType, nil] the simple type, or nil if not found
      def simple_type(namespace, name)
        find_by_namespace(namespace).simple_types[name]
      end

      # Finds a schema by its target namespace.
      #
      # @param namespace [String] the target namespace URI to search for
      # @return [Schema, nil] the schema with the matching target namespace, or nil if not found
      # @todo Consider storing schemas by namespace for O(1) lookup instead of O(n) search
      def find_by_namespace(namespace)
        find { |schema| schema.target_namespace == namespace }
      end
    end
  end
end
