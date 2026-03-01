# frozen_string_literal: true

module WSDL
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
    class Node
      include QName

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
      def initialize(xml_node, collection, context = {})
        @xml_node = xml_node
        @collection = collection
        @context = context

        @kind = xml_node.name.to_sym
        @attributes_hash = extract_attributes(xml_node)
        @namespaces = xml_node.namespaces.freeze
      end

      # @return [Symbol] the XSD element type (:element, :complexType, :sequence, etc.)
      attr_reader :kind

      # @return [Nokogiri::XML::Node] the underlying XML node
      attr_reader :xml_node

      # @return [Hash{String => String}] XML namespace declarations in scope
      attr_reader :namespaces

      # @!group Common Attributes

      # @return [String, nil] the local name of this node
      def name
        @attributes_hash['name']
      end

      # @return [String, nil] the qualified type reference
      def type
        @attributes_hash['type']
      end

      # @return [String, nil] the qualified element/attribute reference
      def ref
        @attributes_hash['ref']
      end

      # @return [String, nil] the base type for restrictions/extensions
      def base
        @attributes_hash['base']
      end

      # @return [String] the use constraint ('optional' or 'required')
      def use
        @attributes_hash['use'] || 'optional'
      end

      # @return [String, nil] the default value
      def default
        @attributes_hash['default']
      end

      # @return [String, nil] the fixed value
      def fixed
        @attributes_hash['fixed']
      end

      # @return [Boolean] whether this element allows nil values (xsi:nil="true")
      def nillable?
        @attributes_hash['nillable'] == 'true'
      end

      # @return [String, nil] the target namespace URI
      def namespace
        @context[:target_namespace]
      end

      # Returns the element form (qualified or unqualified).
      #
      # @return [String] 'qualified' or 'unqualified'
      def form
        @attributes_hash['form'] ||
          (@context[:element_form_default] == 'qualified' ? 'qualified' : 'unqualified')
      end

      # Accesses any attribute from the underlying node.
      #
      # @param attr_name [String] the attribute name
      # @return [String, nil] the attribute value
      def [](attr_name)
        @attributes_hash[attr_name]
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
      # extension base type inheritance.
      #
      # @param memo [Array<Node>] accumulator for recursive traversal
      # @return [Array<Node>] all element definitions found
      def elements(memo = [])
        return memo if ELEMENT_TERMINATORS.include?(kind)

        include_base_type_elements(memo) if kind == :extension

        children.each do |child|
          if ELEMENT_KINDS.include?(child.kind)
            memo << child
          else
            memo = child.elements(memo)
          end
        end

        memo
      end

      # Collects all attribute definitions from this node and descendants.
      #
      # Traverses the type hierarchy to find all xs:attribute definitions.
      # Handles attributeGroup references.
      #
      # @param memo [Array<Node>] accumulator for recursive traversal
      # @return [Array<Node>] all attribute definitions found
      def attributes(memo = [])
        return memo if ATTRIBUTE_TERMINATORS.include?(kind)

        return resolve_attribute_group_ref(memo) if kind == :attributeGroup && ref

        children.each do |child|
          if ATTRIBUTE_KINDS.include?(child.kind)
            memo << child
          else
            memo = child.attributes(memo)
          end
        end

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

      # Returns a unique identifier for this type.
      #
      # Used to detect recursive type definitions during element building.
      #
      # @return [String, nil] the type ID in "namespace:name" format
      def type_id
        return nil unless %i[complexType element].include?(kind)

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
        @attributes_hash['namespace'] || '##any'
      end

      # Returns how wildcard content should be validated.
      #
      # @return [String] 'strict', 'lax', or 'skip'
      def process_contents
        @attributes_hash['processContents'] || 'strict'
      end

      # @!endgroup

      # @!group Cardinality

      # @return [String] the maxOccurs value ('1', 'unbounded', etc.)
      def max_occurs
        @attributes_hash['maxOccurs'] || '1'
      end

      # @return [String] the minOccurs value ('0', '1', etc.)
      def min_occurs
        @attributes_hash['minOccurs'] || '1'
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
          kind: kind,
          name: name,
          type: type,
          ref: ref,
          namespace: namespace
        }
      end

      # @!endgroup

      # Returns a string representation for debugging.
      #
      # @return [String] formatted debug string
      def inspect
        attrs = @attributes_hash.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')
        "#<Schema::Node:#{kind} #{attrs}>"
      end

      private

      # Extracts attributes from XML node into a hash.
      #
      # @param xml_node [Nokogiri::XML::Node] the XML node
      # @return [Hash{String => String}] attribute name to value mapping
      def extract_attributes(xml_node)
        xml_node.attributes.transform_values(&:value)
      end

      # Includes elements from the base type for extensions.
      #
      # @param memo [Array<Node>] accumulator for elements
      # @return [void]
      def include_base_type_elements(memo)
        return unless base

        base_type = resolve_type(base)
        base_type&.elements(memo)
      end

      # Resolves attribute group reference and returns its attributes.
      #
      # @param memo [Array<Node>] accumulator for attributes
      # @return [Array<Node>] attributes from the referenced group
      def resolve_attribute_group_ref(memo)
        group = resolve_attribute_group(ref)
        group ? memo + group.attributes : memo
      end

      # Resolves a qualified type name to a Node.
      #
      # @param qname [String] qualified name (prefix:localName)
      # @return [Node, nil] the resolved type node
      def resolve_type(qname)
        local, ns = expand_qname(qname, @namespaces, @context[:target_namespace])
        @collection&.find_type(ns, local)
      end

      # Resolves a qualified attribute group name to a Node.
      #
      # @param qname [String] qualified name (prefix:localName)
      # @return [Node, nil] the resolved attribute group node
      def resolve_attribute_group(qname)
        local, ns = expand_qname(qname, @namespaces, @context[:target_namespace])
        @collection&.find_attribute_group(ns, local)
      end
    end
  end
end
