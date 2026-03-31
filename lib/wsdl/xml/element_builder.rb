# frozen_string_literal: true

require 'wsdl/xml/element'
require 'wsdl/xml/attribute'

module WSDL
  module XML
    # Builds XML Element trees from WSDL message part definitions.
    #
    # Transforms WSDL message parts into a tree of {Element} objects that
    # represent the structure of SOAP messages. Resolves type references,
    # handles complex and simple types, and detects recursive definitions
    # (both named-type cycles and element-ref cycles) to prevent infinite
    # loops during element building.
    #
    class ElementBuilder # rubocop:disable Metrics/ClassLength -- type-aware serialization adds essential methods
      include Log

      # XSD built-in simple and complex types per XML Schema Part 2 §3.
      #
      # @return [Set<String>]
      XSD_BUILTIN_TYPES = Set.new(%w[
        anyType anySimpleType
        string normalizedString token language Name NCName ID IDREF IDREFS
        ENTITY ENTITIES NMTOKEN NMTOKENS
        boolean
        decimal integer nonPositiveInteger negativeInteger long int short byte
        nonNegativeInteger unsignedLong unsignedInt unsignedShort unsignedByte positiveInteger
        float double
        duration dateTime time date gYearMonth gYear gMonthDay gDay gMonth
        hexBinary base64Binary
        anyURI QName NOTATION
      ]).freeze

      # SOAP Encoding built-in types per SOAP 1.1 §5 and SOAP 1.2 Part 2.
      #
      # Mirrors XSD built-in types (SOAP-ENC types are XSD type equivalents
      # with optional encoding metadata attributes) plus the compound Array type.
      #
      # @return [Set<String>]
      # @see https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383512
      SOAP_ENC_BUILTIN_TYPES = (XSD_BUILTIN_TYPES | Set['Array']).freeze

      # Creates a new ElementBuilder instance.
      #
      # @param schemas [Schema::Collection] the schema collection for resolving types
      # @param limits [Limits, nil] resource limits for DoS protection.
      #   If nil, uses {Limits} defaults.
      # @param issues [Array, nil] optional issues collector for recording build problems
      def initialize(schemas, limits: nil, issues: nil)
        @schemas = schemas
        @limits = limits || Limits.new
        @issues = issues
        @depth_exceeded = false
        @type_cache = {}
      end

      # Builds Element trees from WSDL message parts.
      #
      # Each part can reference either a type (via @type attribute) or an
      # element (via @element attribute). Processes each part and returns
      # the corresponding Element objects.
      #
      # @param parts [Array<Hash>] the message parts to build elements from
      # @return [Array<Element>] the built element trees
      # @raise [ResourceLimitError] if type nesting depth exceeds limits
      def build(parts)
        @depth_exceeded = false
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
        element.min_occurs = '1'
        element.max_occurs = '1'

        handle_type(element, type)
        element.freeze
      end

      # Builds an Element from a part with an @element attribute.
      #
      # @param part [Hash] the part definition with :element and :namespaces keys
      # @return [Element] the built element
      # @raise [UnresolvedReferenceError] if element references cannot be resolved
      def build_element(part)
        result = resolve_part_schema_element(part)
        return nil unless result

        schema_element, namespace = result
        type = find_type_for_element(schema_element)
        element = instantiate_schema_element(schema_element, namespace)

        handle_type(element, type)
        element.freeze
      end

      def resolve_part_schema_element(part)
        namespace, local = QName.resolve(part[:element], namespaces: part[:namespaces])
        schema_element = @schemas.find_element(namespace, local)

        unless schema_element
          record_issue('build_error', "Unable to find element #{part[:element].inspect} " \
                                      "in schema namespace #{namespace.inspect}")
          return nil
        end

        [schema_element, namespace]
      end

      def instantiate_schema_element(schema_element, namespace)
        element = Element.new
        element.name = schema_element.name
        element.form = 'qualified'
        element.namespace = namespace
        element.nillable = schema_element.nillable?
        element.min_occurs = schema_element.min_occurs
        element.max_occurs = schema_element.max_occurs
        element
      end

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
      # @param depth [Integer] the current nesting depth (default: 1)
      # @return [void]
      def handle_type(element, type, depth: 1)
        case type
        when Schema::Node
          handle_schema_node_type(element, type, depth:)
        when String
          element.base_type = type
        end
      end

      # Handles a Schema::Node type based on its kind.
      #
      # @param element [Element] the element to configure
      # @param type [Schema::Node] the schema node
      # @param depth [Integer] the current nesting depth
      # @return [void]
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity -- type dispatch + caching
      def handle_schema_node_type(element, type, depth: 1)
        case type.kind
        when :complexType
          type_id = type.type_id
          element.complex_type_id = type_id

          cache_key = type_id ? "#{type_id}@#{depth}" : nil
          if cache_key && (cached = @type_cache[cache_key])
            element.children = cached[:children]
            element.any_content = cached[:has_any]
            element.attributes = cached[:attributes]
            return
          end

          children_and_wildcards = child_elements(element, type, depth:)
          element.children = children_and_wildcards[:elements]
          element.any_content = children_and_wildcards[:has_any]
          element.attributes = element_attributes(type)

          if cache_key && !children_and_wildcards[:has_recursive]
            @type_cache[cache_key] = {
              children: element.children,
              has_any: element.any_content,
              attributes: element.attributes
            }
          end
        when :simpleType
          apply_simple_type(element, type)
        end
      end
      # rubocop:enable Metrics/AbcSize

      # Applies simple type information to an element or attribute.
      #
      # Handles three derivation methods:
      # - Restriction: Uses the base type directly
      # - List: Sets base_type to the itemType and marks as a list
      # - Union: Uses the first member type as the base type
      #
      # @param target [Element, Attribute] the element or attribute to configure
      # @param type [Schema::Node] the simpleType node
      # @return [void]
      def apply_simple_type(target, type)
        if (item_type = type.list_item_type)
          target.base_type = item_type
          target.list = true
        elsif (member_types = type.union_member_types)
          target.base_type = member_types.split.first
        else
          target.base_type = type.restriction_base
        end
      end

      # Applies type information to an attribute.
      #
      # @param attribute [Attribute] the attribute to configure
      # @param type [Schema::Node, String, nil] the type information
      # @return [void]
      def apply_attribute_type(attribute, type)
        case type
        when Schema::Node
          apply_simple_type(attribute, type) if type.kind == :simpleType
        when String
          attribute.base_type = type
        end
      end

      # Builds Attribute objects from a complex type's attribute definitions.
      #
      # @param type [Schema::Node] the complex type to extract attributes from
      # @return [Array<Attribute>] the built attribute objects
      def element_attributes(type)
        schema_attrs = begin
          type.attributes([], limits: @limits)
        rescue ResourceLimitError => e
          record_issue('resource_limit', e.message)
          []
        end

        schema_attrs.filter_map { |schema_attr|
          attr = Attribute.new

          if schema_attr.ref
            schema_attr = find_attribute(schema_attr.ref, schema_attr.namespaces)
            next unless schema_attr
          end

          attr_type = find_type_for_element(schema_attr)
          apply_attribute_type(attr, attr_type)

          attr.name = schema_attr.name
          attr.use = schema_attr.use

          attr.freeze
        }
      end

      # Builds child Element objects from a complex type's element definitions.
      #
      # Processes each child element in the type, resolving references and
      # types. Detects recursive type definitions to prevent infinite loops.
      # Also detects xs:any wildcards to mark elements allowing arbitrary content.
      #
      # @param parent [Element] the parent element
      # @param type [Schema::Node] the complex type to extract children from
      # @param depth [Integer] the current nesting depth (default: 1)
      # @return [Hash] a hash with :elements (Array<Element>) and :has_any (Boolean)
      # @raise [ResourceLimitError] if nesting depth exceeds max_type_nesting_depth
      # rubocop:disable Metrics/AbcSize, Metrics/BlockLength, Metrics/PerceivedComplexity, Metrics/MethodLength -- cohesive element-building logic
      def child_elements(parent, type, depth: 1)
        return { elements: [], has_any: false } unless within_nesting_depth?(depth, type)

        has_any = false
        has_recursive = false
        elements = []

        resolve_schema_elements(type).each do |child_element|
          if child_element.kind == :any
            has_any = true
            next
          end

          el = Element.new
          el.parent = parent

          max_occurs = child_element['maxOccurs'].to_s
          el.singular = max_occurs.empty? || max_occurs == '1'
          el.min_occurs = child_element.min_occurs
          el.max_occurs = child_element.max_occurs

          original_ref = child_element.ref

          if original_ref
            child_element = find_element(original_ref, child_element.namespaces)
            next unless child_element

            el.form = 'qualified'
            el.element_ref_id = "#{child_element.namespace}:#{child_element.name}"
          else
            el.form = child_element.form
          end

          el.name = child_element.name
          el.namespace = child_element.namespace
          el.nillable = child_element.nillable?

          if recursive_child_definition?(parent, child_element, el)
            el.recursive_type = child_element.type || original_ref
            has_recursive = true # -- used in return hash
          else
            child_type = find_type_for_element(child_element)
            handle_type(el, child_type, depth: depth + 1)
          end

          elements << el.freeze
        end

        { elements:, has_any:, has_recursive: }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/BlockLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength

      # Resolves child elements from a schema type node.
      #
      # Schema::Node returns nil for missing groups/types instead of raising.
      # Catches ResourceLimitError from Schema::Node's count validation.
      #
      # @param type [Schema::Node] the complex type node
      # @return [Array<Schema::Node>] the child elements
      def resolve_schema_elements(type)
        type.elements([], limits: @limits)
      rescue ResourceLimitError => e
        record_issue('resource_limit', e.message)
        []
      end

      # Checks if an element's type or element ref creates a recursive definition.
      #
      # Walks the parent chain once, checking two identity spaces per ancestor:
      # - {Element#complex_type_id} against the resolved type QName (catches
      #   cycles through named complex types)
      # - {Element#element_ref_id} against the built element's ref identity
      #   (catches cycles through global element declarations with anonymous
      #   inline complex types)
      #
      # @param parent [Element] the parent element to start checking from
      # @param element [Schema::Node] the schema element to check for recursion
      # @param built_element [Element] the XML::Element being built (carries element_ref_id)
      # @return [Boolean] true if the element creates a recursive definition
      def recursive_child_definition?(parent, element, built_element) # rubocop:disable Metrics/CyclomaticComplexity
        type_id = resolve_type_id(element)
        ref_id = built_element.element_ref_id

        return false unless type_id || ref_id

        current = parent
        while current
          return true if type_id && current.complex_type_id == type_id
          return true if ref_id && current.element_ref_id == ref_id

          current = current.parent
        end

        false
      end

      # Resolves a schema element's type to a comparable identity string.
      #
      # @param element [Schema::Node] the schema element
      # @return [String, nil] the resolved type identity, or nil if untyped
      def resolve_type_id(element)
        return unless element.type

        namespace, local = QName.resolve(element.type, namespaces: element.namespaces)
        "#{namespace}:#{local}"
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
      # Handles four cases:
      # - Built-in XSD types (returns the qname string)
      # - SOAP encoding built-in types (returns the qname string)
      # - Custom complex types (returns the Node)
      # - Custom simple types (returns the Node)
      #
      # @param qname [String] the qualified type name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node, String] the resolved type
      def find_type(qname, namespaces)
        namespace, local = QName.resolve(qname, namespaces:)

        return qname unless namespace

        if namespace == NS::XSD
          validate_xsd_builtin_type(local, qname)
          return qname
        end

        if [NS::SOAP_ENC_1_1, NS::SOAP_ENC_1_2].include?(namespace)
          validate_soap_enc_builtin_type(local, qname)
          return qname
        end

        type = @schemas.find_type(namespace, local)
        unless type
          record_issue('build_error', "Unable to find type #{qname.inspect} " \
                                      "in schema namespace #{namespace.inspect}")
          return qname
        end

        type
      end

      def validate_xsd_builtin_type(local_name, qname)
        return if XSD_BUILTIN_TYPES.include?(local_name)

        record_issue('build_error', "Unknown XSD built-in type #{qname.inspect}")
      end

      # Validates that a local name is a known SOAP encoding built-in type.
      #
      # @param local_name [String] the unqualified type name
      # @param qname [String] the original qualified name (for error messages)
      # @return [void]
      def validate_soap_enc_builtin_type(local_name, qname)
        return if SOAP_ENC_BUILTIN_TYPES.include?(local_name)

        record_issue('build_error', "Unknown SOAP encoding type #{qname.inspect}")
      end

      # Finds a global element by its qualified name.
      #
      # @param qname [String] the qualified element name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node] the resolved element
      def find_element(qname, namespaces)
        namespace, local = QName.resolve(qname, namespaces:)
        element = @schemas.find_element(namespace, local)

        unless element
          record_issue('build_error', "Unable to find element #{qname.inspect} " \
                                      "in schema namespace #{namespace.inspect}")
        end

        element
      end

      # Finds a global attribute by its qualified name.
      #
      # Attribute refs are best-effort — a missing attribute doesn't break
      # the message structure, only omits metadata.
      #
      # @param qname [String] the qualified attribute name (prefix:localName)
      # @param namespaces [Hash] namespace declarations in scope
      # @return [Schema::Node, nil] the resolved attribute, or nil if not found
      def find_attribute(qname, namespaces)
        namespace, local = QName.resolve(qname, namespaces:)
        @schemas.find_attribute(namespace, local)
      end

      # Checks nesting depth against limits.
      #
      # When exceeded, sets +@depth_exceeded+ to stop ALL further recursion
      # for this builder instance — not just the current subtree. Without
      # this, deeply nested types cause exponential blowup as each sibling
      # branch independently recurses to the depth limit.
      #
      # @param depth [Integer] the current nesting depth
      # @param type [Schema::Node] the type being processed (for error messages)
      # @return [Boolean] true if within limits, false if exceeded
      def within_nesting_depth?(depth, type)
        return false if @depth_exceeded
        return true unless @limits.max_type_nesting_depth
        return true if depth <= @limits.max_type_nesting_depth

        @depth_exceeded = true
        record_issue('resource_limit',
          "Type nesting depth #{depth} exceeds limit of #{@limits.max_type_nesting_depth} " \
          "while processing type #{type.name.inspect}")
        false
      end

      # Records a build issue if an issues collector is available.
      #
      # @param type [String] the issue type ('build_error' or 'resource_limit')
      # @param error [String] description of the problem
      # @return [void]
      def record_issue(type, error)
        @issues&.push('type' => type, 'error' => error)
      end
    end
  end
end
