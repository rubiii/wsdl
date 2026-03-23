# frozen_string_literal: true

module WSDL
  module Schema
    # Represents a parsed XML Schema (XSD) document.
    #
    # Parses an xs:schema element and provides access to its components:
    # elements, complex types, simple types, attributes, and attribute groups.
    # Also tracks schema imports and includes for resolving cross-schema refs.
    #
    # @example
    #   definition = Schema::Definition.new(schema_node, collection)
    #   definition.target_namespace  # => "http://example.com"
    #   definition.elements['User']  # => Node
    #
    class Definition
      include Log

      # Creates a new Definition by parsing an XML Schema node.
      #
      # @param schema_node [Nokogiri::XML::Node] the xs:schema element
      # @param collection [Collection] the parent collection for resolving refs
      # @param source_location [String, nil] where this schema was loaded from
      def initialize(schema_node, collection, source_location = nil)
        @schema_node = schema_node
        @collection = collection
        @source_location = source_location

        @target_namespace = schema_node['targetNamespace']
        @element_form_default = schema_node['elementFormDefault'] || 'unqualified'

        @elements = {}
        @complex_types = {}
        @simple_types = {}
        @attributes = {}
        @attribute_groups = {}
        @groups = {}
        @imports = {}
        @includes = []

        parse
      end

      # @return [String, nil] the target namespace URI
      attr_reader :target_namespace

      # @return [String] 'qualified' or 'unqualified'
      attr_reader :element_form_default

      # @return [String, nil] the location this schema was loaded from
      attr_reader :source_location

      # @return [Hash{String => Node}] global element declarations
      attr_reader :elements

      # @return [Hash{String => Node}] complex type definitions
      attr_reader :complex_types

      # @return [Hash{String => Node}] simple type definitions
      attr_reader :simple_types

      # @return [Hash{String => Node}] global attribute declarations
      attr_reader :attributes

      # @return [Hash{String => Node}] attribute group definitions
      attr_reader :attribute_groups

      # @return [Hash{String => Node}] model group definitions
      attr_reader :groups

      # @return [Hash{String => String}] namespace to schemaLocation mappings
      attr_reader :imports

      # @return [Array<String>] schemaLocation values for includes
      attr_reader :includes

      # Merges another definition's contents into this one.
      #
      # Used for xs:include processing where the included schema's
      # components should be merged as if defined locally.
      #
      # Logs a warning if the other definition contains components with the
      # same name as existing ones, since per the XSD spec xs:include
      # components should not conflict.
      #
      # @param other [Definition] the definition to merge
      # @return [void]
      def merge(other)
        merge_with_conflict_detection(@elements, other.elements, :element)
        merge_with_conflict_detection(@complex_types, other.complex_types, :complex_type)
        merge_with_conflict_detection(@simple_types, other.simple_types, :simple_type)
        merge_with_conflict_detection(@attributes, other.attributes, :attribute)
        merge_with_conflict_detection(@attribute_groups, other.attribute_groups, :attribute_group)
        merge_with_conflict_detection(@groups, other.groups, :group)
        @imports.merge!(other.imports)
        @includes.concat(other.includes)
      end

      private

      # Merges other_hash into target, logging a warning for each key conflict.
      #
      # @param target [Hash{String => Node}] the hash to merge into
      # @param other_hash [Hash{String => Node}] the hash to merge from
      # @param component_type [Symbol] the type of schema component (for logging)
      # @return [void]
      def merge_with_conflict_detection(target, other_hash, component_type)
        conflicting_keys = target.keys & other_hash.keys
        conflicting_keys.each do |key|
          ns = @target_namespace || '(no namespace)'
          logger.warn(
            "Schema #{component_type} '#{key}' in namespace '#{ns}' " \
            'is defined in multiple xs:include schemas. The duplicate definition will be used.'
          )
        end
        target.merge!(other_hash)
      end

      # Returns the context hash for creating child nodes.
      #
      # @return [Hash] context with namespace and form default
      def context
        { target_namespace: @target_namespace, element_form_default: @element_form_default }
      end

      # Parses the schema node and populates component collections.
      #
      # @return [void]
      # rubocop:disable Metrics/CyclomaticComplexity -- simple case statement, readable as-is
      def parse
        @schema_node.element_children.each do |child|
          case child.name
          when 'element'        then store(@elements, child)
          when 'complexType'    then store(@complex_types, child)
          when 'simpleType'     then store(@simple_types, child)
          when 'attribute'      then store(@attributes, child)
          when 'attributeGroup' then store(@attribute_groups, child)
          when 'group'          then store(@groups, child)
          when 'import'         then parse_import(child)
          when 'include'        then parse_include(child)
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Stores a parsed node in the given collection.
      #
      # @param collection [Hash] the collection to store in
      # @param child [Nokogiri::XML::Node] the child node to parse
      # @return [void]
      def store(collection, child)
        collection[child['name']] = Node.new(child, @collection, context)
      end

      # Parses an xs:import element.
      #
      # @param child [Nokogiri::XML::Node] the import element
      # @return [void]
      def parse_import(child)
        @imports[child['namespace']] = child['schemaLocation']
      end

      # Parses an xs:include element.
      #
      # @param child [Nokogiri::XML::Node] the include element
      # @return [void]
      def parse_include(child)
        location = child['schemaLocation']
        @includes << location if location
      end
    end
  end
end
