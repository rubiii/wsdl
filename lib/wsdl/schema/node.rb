# frozen_string_literal: true

module WSDL
  # XML Schema (XSD) parsing and representation.
  #
  # This module provides classes for parsing XML Schema definitions embedded
  # in WSDL documents and resolving type references.
  module Schema
    # Unified representation of all XSD schema nodes.
    #
    # Instead of a deep class hierarchy where most classes are empty,
    # this single class represents all XSD constructs and uses the {#kind}
    # attribute to determine behavior.
    #
    # @example Basic usage
    #   node = Schema::Node.new(nokogiri_node, collection, context)
    #   node.kind        # => :complexType
    #   node.name        # => "UserType"
    #   node.elements    # => [Node, Node, ...]
    #
    # @example Pattern matching (Ruby 3.0+)
    #   case node
    #   in { kind: :element, name: }
    #     puts "Element: #{name}"
    #   in { kind: :complexType }
    #     puts "Complex type with #{node.elements.count} elements"
    #   end
    #
    # rubocop:disable Metrics/ClassLength
    class Node
      # Node kinds that terminate element collection (contain no child elements).
      ELEMENT_TERMINATORS = Set[
        :attribute,
        :annotation,
        :simpleContent
      ].freeze

      # Node kinds that terminate attribute collection.
      ATTRIBUTE_TERMINATORS = Set[
        :annotation
      ].freeze

      # Node kinds representing actual schema elements.
      ELEMENT_KINDS = Set[:element, :any].freeze

      # Node kinds representing attributes.
      ATTRIBUTE_KINDS = Set[:attribute].freeze

      # Node kinds that can have inline type definitions.
      INLINE_TYPE_KINDS = Set[:complexType, :simpleType].freeze

      # Creates a new Node from an XSD element.
      #
      # @param xml_node [Nokogiri::XML::Node] the XSD element node
      # @param collection [Collection] the schema collection for resolving refs
      # @param context [Hash] schema context
      # @option context [String] :target_namespace the target namespace URI
      # @option context [String] :element_form_default 'qualified' or 'unqualified'
      # @option context [Hash] :schema_namespaces cached namespace declarations from the parent schema
      def initialize(xml_node, collection, context = {})
        @xml_node = xml_node
        @collection = collection
        @context = context

        @kind = xml_node.name.to_sym
      end

      # @return [Symbol] the XSD element type (:element, :complexType, :sequence, etc.)
      attr_reader :kind

      # @return [Nokogiri::XML::Node] the underlying XML node
      attr_reader :xml_node

      # Returns XML namespace declarations in scope.
      #
      # Computed lazily because many intermediate schema nodes (sequence,
      # all, choice, etc.) never have their namespaces accessed externally.
      # Reuses the cached schema-level namespaces when the node has no
      # local namespace declarations, avoiding expensive Nokogiri traversal.
      #
      # @return [Hash{String => String}] XML namespace declarations in scope
      def namespaces
        @namespaces ||= if @context[:schema_namespaces] && @xml_node.namespace_definitions.empty?
          @context[:schema_namespaces]
        else
          @xml_node.namespaces.freeze
        end
      end

      # @!group Common Attributes

      # @return [String, nil] the local name of this node
      def name
        @xml_node['name']
      end

      # @return [String, nil] the qualified type reference
      def type
        @xml_node['type']
      end

      # @return [String, nil] the qualified element/attribute reference
      def ref
        @xml_node['ref']
      end

      # @return [String, nil] the base type for restrictions/extensions
      def base
        @xml_node['base']
      end

      # @return [String] the use constraint ('optional' or 'required')
      def use
        @xml_node['use'] || 'optional'
      end

      # @return [String, nil] the default value
      def default
        @xml_node['default']
      end

      # @return [String, nil] the fixed value
      def fixed
        @xml_node['fixed']
      end

      # @return [Boolean] whether this element allows nil values (xsi:nil="true")
      def nillable?
        @xml_node['nillable'] == 'true'
      end

      # @return [String, nil] the target namespace URI
      def namespace
        @context[:target_namespace]
      end

      # Returns the element form (qualified or unqualified).
      #
      # @return [String] 'qualified' or 'unqualified'
      def form
        @xml_node['form'] ||
          (@context[:element_form_default] == 'qualified' ? 'qualified' : 'unqualified')
      end

      # Accesses any attribute from the underlying node.
      #
      # @param attr_name [String] the attribute name
      # @return [String, nil] the attribute value
      def [](attr_name)
        @xml_node[attr_name]
      end

      # @!endgroup

      # @!group Children & Traversal

      # Returns the parsed child nodes.
      #
      # @return [Array<Node>] the child nodes
      def children
        @children ||= @xml_node.element_children.map { |n| Node.new(n, @collection, @context) }
      end

      # Returns whether this node has no meaningful content.
      #
      # A node is considered empty if it has no children, or if its only
      # children are empty compositors (sequence, all, choice with no elements).
      #
      # @return [Boolean] true if the node has no meaningful content
      def empty?
        return true if children.empty?

        # Check if all children are empty compositors
        compositor_kinds = %i[sequence all choice]
        children.all? do |child|
          compositor_kinds.include?(child.kind) && child.children.empty?
        end
      end

      # Collects all element definitions from this node and descendants.
      #
      # Traverses the type hierarchy to find all xs:element definitions,
      # which represent the actual content model of complex types. Handles
      # extension base type inheritance. Skips unresolvable references
      # and continues collecting.
      #
      # @param memo [Array<Node>] accumulator for recursive traversal
      # @param limits [Limits, nil] resource limits for validation
      # @return [Array<Node>] all element definitions found
      # @raise [ResourceLimitError] if element count exceeds max_elements_per_type
      def elements(memo = [], limits: nil)
        return memo if ELEMENT_TERMINATORS.include?(kind)
        return resolve_group_ref(memo, limits:) if kind == :group && ref

        if @cached_elements
          memo.concat(@cached_elements)
          validate_element_count!(memo.size, limits)
          return memo
        end

        before = memo.size
        include_base_type_elements(memo, limits:) if kind == :extension
        collect_child_elements(memo, limits:)
        @cached_elements = memo[before..].freeze if kind == :complexType
        memo
      end

      # Collects all attribute definitions from this node and descendants.
      #
      # Traverses the type hierarchy to find all xs:attribute definitions.
      # Handles attributeGroup references. Skips unresolvable references
      # and continues collecting.
      #
      # @param memo [Array<Node>] accumulator for recursive traversal
      # @param limits [Limits, nil] resource limits for validation
      # @return [Array<Node>] all attribute definitions found
      # @raise [ResourceLimitError] if attribute count exceeds max_attributes_per_element
      def attributes(memo = [], limits: nil)
        return memo if ATTRIBUTE_TERMINATORS.include?(kind)
        return resolve_attribute_group_ref(memo, limits:) if kind == :attributeGroup && ref

        if @cached_attributes
          memo.concat(@cached_attributes)
          validate_attribute_count!(memo.size, limits)
          return memo
        end

        before = memo.size
        memo = collect_child_attributes(memo, limits:)
        @cached_attributes = memo[before..].freeze if kind == :complexType
        memo
      end

      # @!endgroup

      # @!group Type Resolution

      # Returns the inline type definition if present.
      #
      # An inline type is a complex or simple type defined directly within
      # the element rather than referenced by name. Skips annotation elements.
      #
      # @return [Node, nil] the inline type, or nil if none
      def inline_type
        children.find { |c| INLINE_TYPE_KINDS.include?(c.kind) }
      end

      # Returns the base type from a restriction child.
      #
      # @return [String, nil] the base type name
      def restriction_base
        restriction = children.find { |c| c.kind == :restriction }
        restriction&.base
      end

      # Returns the item type from a list derivation.
      #
      # @return [String, nil] the itemType attribute value
      def list_item_type
        list = children.find { |c| c.kind == :list }
        list&.[]('itemType')
      end

      # Returns the member types from a union derivation.
      #
      # @return [String, nil] the memberTypes attribute value
      def union_member_types
        union = children.find { |c| c.kind == :union }
        union&.[]('memberTypes')
      end

      # Returns a unique identifier for this type.
      #
      # Used to detect recursive type definitions during element building.
      #
      # @return [String, nil] the type ID in "namespace:name" format
      def type_id
        return nil unless %i[complexType element].include?(kind)
        return nil unless name

        "#{namespace}:#{name}"
      end

      # @!endgroup

      # @!group xs:any Wildcard Support

      # @return [Boolean] true if this is an xs:any wildcard
      def any?
        kind == :any
      end

      # Returns the namespace constraint for wildcards.
      #
      # @return [String] '##any', '##other', '##local', '##targetNamespace', or a URI
      def namespace_constraint
        @xml_node['namespace'] || '##any'
      end

      # Returns how wildcard content should be validated.
      #
      # @return [String] 'strict', 'lax', or 'skip'
      def process_contents
        @xml_node['processContents'] || 'strict'
      end

      # @!endgroup

      # @!group Cardinality

      # @return [String] the maxOccurs value ('1', 'unbounded', etc.)
      def max_occurs
        @xml_node['maxOccurs'] || '1'
      end

      # @return [String] the minOccurs value ('0', '1', etc.)
      def min_occurs
        @xml_node['minOccurs'] || '1'
      end

      # Returns whether this element can appear multiple times.
      #
      # @return [Boolean] true if maxOccurs is unbounded or > 1
      def multiple?
        max_occurs == 'unbounded' || max_occurs.to_i > 1
      end

      # Returns whether this element is optional.
      #
      # @return [Boolean] true if minOccurs is 0
      def optional?
        min_occurs == '0'
      end

      # Returns whether this element is required.
      #
      # @return [Boolean] true if minOccurs is not 0
      def required?
        !optional?
      end

      # @!endgroup

      # @!group Pattern Matching

      # Supports Ruby pattern matching.
      #
      # @param _keys [Array<Symbol>, nil] keys to extract (unused, returns all keys)
      # @return [Hash] deconstructed key-value pairs
      #
      # @example
      #   case node
      #   in { kind: :element, name: "User" }
      #     # matches element named "User"
      #   end
      def deconstruct_keys(_keys)
        {
          kind:,
          name:,
          type:,
          ref:,
          namespace:
        }
      end

      # @!endgroup

      # Returns a string representation for debugging.
      #
      # @return [String] formatted debug string
      def inspect
        attrs = @xml_node.attribute_nodes.map { |a| "#{a.name}=#{a.value.inspect}" }.join(' ')
        "#<Schema::Node:#{kind} #{attrs}>"
      end

      private

      # Collects element nodes from immediate children.
      #
      # Walks children, appending element/any nodes to the memo and
      # recursing into compositor nodes (sequence, all, choice).
      #
      # @param memo [Array<Node>] accumulator for elements
      # @param limits [Limits, nil] resource limits for validation
      # @return [void]
      def collect_child_elements(memo, limits:)
        children.each do |child|
          if ELEMENT_KINDS.include?(child.kind)
            memo << child
            validate_element_count!(memo.size, limits)
          else
            child.elements(memo, limits:)
          end
        end
      end

      # Collects attribute nodes from immediate children.
      #
      # Walks children, appending attribute nodes to the memo and
      # recursing into non-attribute nodes. Returns the memo because
      # attribute group resolution may produce a new array.
      #
      # @param memo [Array<Node>] accumulator for attributes
      # @param limits [Limits, nil] resource limits for validation
      # @return [Array<Node>] the (possibly new) memo array
      def collect_child_attributes(memo, limits:)
        children.each do |child|
          if ATTRIBUTE_KINDS.include?(child.kind)
            memo << child
            validate_attribute_count!(memo.size, limits)
          else
            memo = child.attributes(memo, limits:)
          end
        end
        memo
      end

      # Includes elements from the base type for extensions.
      #
      # @param memo [Array<Node>] accumulator for elements
      # @param limits [Limits, nil] resource limits for validation
      # @return [void]
      def include_base_type_elements(memo, limits: nil)
        return unless base

        base_type = resolve_type(base)
        base_type&.elements(memo, limits:)
      end

      # Resolves model group reference and returns its elements.
      #
      # @param memo [Array<Node>] accumulator for elements
      # @param limits [Limits, nil] resource limits for validation
      # @return [Array<Node>] elements from the referenced group
      def resolve_group_ref(memo, limits: nil)
        group = resolve_group(ref)
        group ? group.elements(memo, limits:) : memo
      end

      # Resolves a qualified model group name to a Node.
      #
      # @param qname [String] qualified name (prefix:localName)
      # @return [Node, nil] the resolved group node, or nil if not found
      def resolve_group(qname)
        namespace, local = QName.resolve(qname, namespaces:, default_namespace: @context[:target_namespace])
        @collection&.find_group(namespace, local)
      end

      # Resolves attribute group reference and returns its attributes.
      #
      # @param memo [Array<Node>] accumulator for attributes
      # @param limits [Limits, nil] resource limits for validation
      # @return [Array<Node>] attributes from the referenced group
      def resolve_attribute_group_ref(memo, limits: nil)
        group = resolve_attribute_group(ref)
        group ? memo + group.attributes([], limits:) : memo
      end

      # Resolves a qualified type name to a Node.
      #
      # @param qname [String] qualified name (prefix:localName)
      # @return [Node, nil] the resolved type node, or nil if not found
      def resolve_type(qname)
        namespace, local = QName.resolve(qname, namespaces:, default_namespace: @context[:target_namespace])
        @collection&.find_type(namespace, local)
      end

      # Resolves a qualified attribute group name to a Node.
      #
      # @param qname [String] qualified name (prefix:localName)
      # @return [Node, nil] the resolved attribute group node, or nil if not found
      def resolve_attribute_group(qname)
        namespace, local = QName.resolve(qname, namespaces:, default_namespace: @context[:target_namespace])
        @collection&.find_attribute_group(namespace, local)
      end

      # Validates element count against limits.
      #
      # @param count [Integer] the current element count
      # @param limits [Limits, nil] resource limits for validation
      # @raise [ResourceLimitError] if count exceeds max_elements_per_type
      def validate_element_count!(count, limits)
        return unless limits&.max_elements_per_type
        return if count <= limits.max_elements_per_type

        raise ResourceLimitError.new(
          "Element count #{count} in type #{name.inspect} exceeds limit of #{limits.max_elements_per_type}." \
          "\nTo increase, use: limits: { max_elements_per_type: #{count} }",
          limit_name: :max_elements_per_type,
          limit_value: limits.max_elements_per_type,
          actual_value: count
        )
      end

      # Validates attribute count against limits.
      #
      # @param count [Integer] the current attribute count
      # @param limits [Limits, nil] resource limits for validation
      # @raise [ResourceLimitError] if count exceeds max_attributes_per_element
      def validate_attribute_count!(count, limits)
        return unless limits&.max_attributes_per_element
        return if count <= limits.max_attributes_per_element

        raise ResourceLimitError.new(
          "Attribute count #{count} in element #{name.inspect} exceeds limit of " \
          "#{limits.max_attributes_per_element}." \
          "\nTo increase, use: limits: { max_attributes_per_element: #{count} }",
          limit_name: :max_attributes_per_element,
          limit_value: limits.max_attributes_per_element,
          actual_value: count
        )
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
