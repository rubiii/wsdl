# frozen_string_literal: true

require 'wsdl/xs/types'

class WSDL
  class XS
    # Represents a parsed XML Schema (XSD) document.
    #
    # This class parses an XML Schema and provides access to its components
    # including elements, complex types, simple types, attributes, and
    # attribute groups. It also tracks schema imports and includes for
    # resolving cross-schema references.
    #
    # @api private
    #
    class Schema
      # Creates a new Schema by parsing an XML Schema node.
      #
      # @param schema [Nokogiri::XML::Node] the xs:schema element
      # @param schemas [SchemaCollection] the parent schema collection for resolving references
      # @param source_location [String, nil] the location this schema was loaded from
      def initialize(schema, schemas, source_location = nil)
        @schema = schema
        @schemas = schemas
        @source_location = source_location

        @target_namespace     = @schema['targetNamespace']
        @element_form_default = @schema['elementFormDefault'] || 'unqualified'

        @attributes       = {}
        @attribute_groups = {}
        @elements         = {}
        @complex_types    = {}
        @simple_types     = {}
        @imports          = {}
        @includes         = []

        parse
      end

      # @!attribute [rw] target_namespace
      #   The target namespace URI for this schema.
      #   @return [String, nil] the target namespace
      attr_accessor :target_namespace

      # @!attribute [rw] element_form_default
      #   The default form for local element declarations.
      #   @return [String] 'qualified' or 'unqualified' (default)
      attr_accessor :element_form_default

      # @!attribute [rw] source_location
      #   The location this schema was loaded from.
      #   Used for resolving relative imports/includes.
      #   @return [String, nil] the source file path or URL
      attr_accessor :source_location

      # @!attribute [rw] imports
      #   Schema import declarations (namespace => schemaLocation).
      #   @return [Hash<String, String>] namespace to schema location mappings
      attr_accessor :imports

      # @!attribute [rw] includes
      #   Schema include declarations (array of schemaLocation strings).
      #   Includes bring in components from the same namespace.
      #   @return [Array<String>] schema locations to include
      attr_accessor :includes

      # @!attribute [rw] attributes
      #   Global attribute declarations in this schema.
      #   @return [Hash<String, Attribute>] attribute name to attribute mappings
      attr_accessor :attributes

      # @!attribute [rw] attribute_groups
      #   Attribute group declarations in this schema.
      #   @return [Hash<String, AttributeGroup>] group name to attribute group mappings
      attr_accessor :attribute_groups

      # @!attribute [rw] elements
      #   Global element declarations in this schema.
      #   @return [Hash<String, Element>] element name to element mappings
      attr_accessor :elements

      # @!attribute [rw] complex_types
      #   Complex type definitions in this schema.
      #   @return [Hash<String, ComplexType>] type name to complex type mappings
      attr_accessor :complex_types

      # @!attribute [rw] simple_types
      #   Simple type definitions in this schema.
      #   @return [Hash<String, SimpleType>] type name to simple type mappings
      attr_accessor :simple_types

      # Merges another schema's contents into this schema.
      #
      # This is used for xs:include processing, where the included schema's
      # components should be merged into the including schema as if they
      # were defined there. Both schemas must have the same target namespace
      # (or the included schema can have no namespace).
      #
      # @param other [Schema] the schema to merge into this one
      # @return [void]
      def merge(other)
        @attributes.merge!(other.attributes)
        @attribute_groups.merge!(other.attribute_groups)
        @elements.merge!(other.elements)
        @complex_types.merge!(other.complex_types)
        @simple_types.merge!(other.simple_types)

        # Also merge any imports/includes from the included schema
        @imports.merge!(other.imports)
        @includes.concat(other.includes)
      end

      private

      # Parses the schema node and populates the component collections.
      #
      # Iterates through child elements and categorizes them into the
      # appropriate collection based on their element type.
      #
      # @return [void]
      # rubocop:disable Metrics/CyclomaticComplexity -- simple case statement, very readable as-is
      def parse
        schema = {
          target_namespace: @target_namespace,
          element_form_default: @element_form_default
        }

        @schema.element_children.each do |node|
          case node.name
          when 'attribute'      then store_element(@attributes, node, schema)
          when 'attributeGroup' then store_element(@attribute_groups, node, schema)
          when 'element'        then store_element(@elements, node, schema)
          when 'complexType'    then store_element(@complex_types, node, schema)
          when 'simpleType'     then store_element(@simple_types, node, schema)
          when 'import'         then store_import(node)
          when 'include'        then store_include(node)
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Stores a parsed schema element in the appropriate collection.
      #
      # @param collection [Hash] the collection to store the element in
      # @param node [Nokogiri::XML::Node] the element node to parse
      # @param schema [Hash] schema context information (namespace, form defaults)
      # @return [void]
      def store_element(collection, node, schema)
        collection[node['name']] = XS.build(node, @schemas, schema)
      end

      # Stores an import declaration.
      #
      # @param node [Nokogiri::XML::Node] the xs:import element
      # @return [void]
      def store_import(node)
        @imports[node['namespace']] = node['schemaLocation']
      end

      # Stores an include declaration.
      #
      # @param node [Nokogiri::XML::Node] the xs:include element
      # @return [void]
      def store_include(node)
        schema_location = node['schemaLocation']
        @includes << schema_location if schema_location
      end
    end
  end
end
