# frozen_string_literal: true

class WSDL
  # XML Schema (XSD) type classes for representing schema components.
  #
  # This module contains classes that represent various XML Schema elements
  # and type definitions. They are used to parse and traverse XSD documents
  # embedded within WSDL files or imported externally.
  #
  # @api private
  #
  class XS
    # Base class for all XML Schema type representations.
    #
    # Provides common functionality for parsing XSD nodes, accessing
    # child elements, and collecting nested elements and attributes
    # from the type hierarchy.
    #
    class BaseType
      # Creates a new BaseType from an XML Schema node.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context (target namespace, form defaults)
      def initialize(node, schemas, schema = {})
        @node = node
        @schemas = schemas
        @schema = schema
      end

      # @return [Nokogiri::XML::Node] the underlying XML node
      attr_reader :node

      # Returns an attribute value from the underlying node.
      #
      # @param key [String] the attribute name
      # @return [String, nil] the attribute value
      def [](key)
        @node[key]
      end

      # Returns whether this type has no meaningful content.
      #
      # @return [Boolean] true if there are no children or the first child is empty
      def empty?
        children.empty? || children.first.empty?
      end

      # Returns the parsed child elements of this type.
      #
      # Child elements are recursively parsed into their appropriate
      # XS type classes.
      #
      # @return [Array<BaseType>] the parsed child type objects
      def children
        @children ||= @node.element_children.map { |child| XS.build(child, @schemas, @schema) }
      end

      # Recursively collects all element definitions from this type and its children.
      #
      # Traverses the type hierarchy to find all xs:element definitions,
      # which represent the actual content model of complex types.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Element>] all element definitions found
      def collect_child_elements(memo = [])
        children.each do |child|
          if child.is_a? Element
            memo << child
          else
            memo = child.collect_child_elements(memo)
          end
        end

        memo
      end

      # Recursively collects all attribute definitions from this type and its children.
      #
      # Traverses the type hierarchy to find all xs:attribute definitions.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Attribute>] all attribute definitions found
      def collect_attributes(memo = [])
        children.each do |child|
          if child.is_a? Attribute
            memo << child
          else
            memo = child.collect_attributes(memo)
          end
        end

        memo
      end

      # Returns a string representation of this type for debugging.
      #
      # @return [String] a formatted string with the class name and node attributes
      def inspect
        attributes = @node
          .attributes
          .each_with_object({}) { |(k, attr), memo|
            memo[k.to_s] = attr.value
          }

        formatted_attributes = attributes
          .map { |k, v| format('%<key>s="%<value>s"', key: k, value: v) }
          .join(' ')

        format('<%<class>s %<attributes>s>', class: self.class, attributes: formatted_attributes)
      end
    end

    # Base class for primary XSD type definitions (elements, types).
    #
    # Extends {BaseType} with additional properties common to named
    # schema components: name, namespace, and form (qualified/unqualified).
    #
    class PrimaryType < BaseType
      # Creates a new PrimaryType with namespace and form information.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context with :target_namespace and :element_form_default
      def initialize(node, schemas, schema = {})
        super

        @namespace = schema[:target_namespace]
        @element_form_default = schema[:element_form_default]

        @name = node['name']
        # Because you've overriden the form method, you don't need to set
        # unqualified as the default when no form is specified.
        # @form = node['form'] || 'unqualified'
        @form = node['form']

        @namespaces = node.namespaces
      end

      # @return [String, nil] the local name of this type
      attr_reader :name

      # @return [String, nil] the target namespace URI
      attr_reader :namespace

      # @return [Hash<String, String>] namespace declarations in scope (xmlns:prefix => URI)
      attr_reader :namespaces

      # Returns the element form (qualified or unqualified).
      #
      # If no explicit form is set, uses the schema's elementFormDefault.
      # Falls back to 'unqualified' if neither is specified.
      #
      # @return [String] 'qualified' or 'unqualified'
      def form
        if @form
          @form
        elsif @element_form_default == 'qualified'
          'qualified'
        else
          'unqualified'
        end
      end
    end

    # Represents an xs:simpleType definition.
    #
    # Simple types define restrictions on built-in types or other simple
    # types. They contain only text content, not child elements.
    #
    class SimpleType < PrimaryType
      # Returns the base type for this simple type restriction.
      #
      # Looks for an xs:restriction child element and returns its
      # base attribute value.
      #
      # @return [String, nil] the base type name (e.g., 'xsd:string')
      def base
        child = @node.element_children.first
        local = child.name.split(':').last

        child['base'] if local == 'restriction'
      end
    end

    # Represents an xs:element definition.
    #
    # Elements can be global (top-level) or local (within complex types).
    # They may reference a type via @type attribute, reference another
    # element via @ref, or contain an inline type definition.
    #
    class Element < PrimaryType
      # Creates a new Element with type and ref information.
      #
      # @param node [Nokogiri::XML::Node] the XSD element node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context information
      def initialize(node, schemas, schema = {})
        super

        @type = node['type']
        @ref  = node['ref']
      end

      # @return [String, nil] the qualified type name (if using @type attribute)
      attr_reader :type

      # @return [String, nil] the qualified element reference (if using @ref attribute)
      attr_reader :ref

      # Returns the inline type definition, if any.
      #
      # An inline type is a complex or simple type defined directly within
      # the element rather than referenced by name. Skips annotation elements.
      #
      # @return [ComplexType, SimpleType, nil] the inline type, or nil if none
      def inline_type
        children.detect { |child| child.node.node_name.downcase != 'annotation' }
      end
    end

    # Represents an xs:complexType definition.
    #
    # Complex types define elements that can contain child elements
    # and/or attributes. They define the content model through
    # compositors (sequence, choice, all) and may extend or restrict
    # other types.
    #
    class ComplexType < PrimaryType
      # Returns all child element definitions within this complex type.
      #
      # Delegates to {BaseType#collect_child_elements} to recursively
      # gather elements from nested compositors.
      #
      # @return [Array<Element>] the child element definitions
      alias elements collect_child_elements

      # Returns all attribute definitions for this complex type.
      #
      # Delegates to {BaseType#collect_attributes} to recursively
      # gather attributes from nested groups.
      #
      # @return [Array<Attribute>] the attribute definitions
      alias attributes collect_attributes

      # Returns a unique identifier for this complex type.
      #
      # The ID is used to detect recursive type definitions during
      # element building.
      #
      # @return [String] the type ID in "namespace:name" format
      def id
        [namespace, name].join(':')
      end
    end

    # Represents an xs:extension within complexContent or simpleContent.
    #
    # Extensions add additional elements or attributes to a base type.
    # The base type's content is inherited and extended with new definitions.
    #
    class Extension < BaseType
      # Collects child elements including those inherited from the base type.
      #
      # First resolves the base type and includes its elements, then
      # adds any elements defined directly in this extension.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Element>] all element definitions including inherited ones
      def collect_child_elements(memo = [])
        if @node['base']
          local, nsid = @node['base'].split(':').reverse
          # When there's no prefix (nsid is nil), use the schema's target namespace
          namespace = nsid ? @node.namespaces["xmlns:#{nsid}"] : @schema[:target_namespace]

          if (complex_type = @schemas.complex_type(namespace, local))
            memo += complex_type.elements

          # TODO: can we find a testcase for this?
          else # if simple_type = @schemas.simple_type(namespace, local)
            raise 'simple type extension?!'
            # memo << simple_type
          end
        end

        super
      end
    end

    # Represents any unrecognized or generic XSD element.
    #
    # Used as a fallback when no specific type class is defined
    # for an XSD element type.
    #
    class AnyType        < BaseType; end

    # Represents xs:complexContent for complex type derivation.
    class ComplexContent < BaseType; end

    # Represents xs:restriction for type restrictions.
    class Restriction    < BaseType; end

    # Represents xs:all compositor (unordered elements, each appearing 0-1 times).
    class All            < BaseType; end

    # Represents xs:sequence compositor (ordered elements).
    class Sequence       < BaseType; end

    # Represents xs:choice compositor (one of several element alternatives).
    class Choice         < BaseType; end

    # Represents xs:enumeration facet within a restriction.
    class Enumeration    < BaseType; end

    # Represents an xs:attribute definition.
    #
    # Attributes define named value properties on elements. They can
    # be optional or required, and may have default or fixed values.
    #
    class Attribute < BaseType
      # Creates a new Attribute with its properties.
      #
      # @param node [Nokogiri::XML::Node] the XSD attribute node
      # @param schemas [SchemaCollection] the schema collection for resolving references
      # @param schema [Hash] schema context information
      def initialize(node, schemas, schema = {})
        super

        @name = node['name']
        @type = node['type']
        @ref  = node['ref']

        @use     = node['use'] || 'optional'
        @default = node['default']
        @fixed   = node['fixed']

        @namespaces = node.namespaces
      end

      # @return [String, nil] the local name of this attribute
      attr_reader :name

      # @return [String, nil] the qualified type name
      attr_reader :type

      # @return [String, nil] the qualified attribute reference (if using @ref)
      attr_reader :ref

      # @return [Hash<String, String>] namespace declarations in scope
      attr_reader :namespaces

      # @return [String] the use constraint ('optional' or 'required')
      attr_reader :use

      # @return [String, nil] the default value for this attribute
      attr_reader :default

      # @return [String, nil] the fixed value for this attribute
      attr_reader :fixed

      # Returns the inline type definition, if any.
      #
      # @return [SimpleType, nil] the inline simple type, or nil if none
      def inline_type
        children.first
      end

      # Stop searching for child elements within attributes.
      #
      # Attributes cannot contain child elements, so this returns
      # an empty array to terminate the recursive search.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end

    # Represents an xs:attributeGroup definition or reference.
    #
    # Attribute groups allow reusing sets of attribute declarations
    # across multiple complex types.
    #
    class AttributeGroup < BaseType
      # Returns all attributes in this group including referenced groups.
      #
      # Delegates to {BaseType#collect_attributes}.
      #
      # @return [Array<Attribute>] the attribute definitions
      alias attributes collect_attributes

      # Collects attributes including those from referenced attribute groups.
      #
      # If this is a reference (@ref), resolves the referenced group
      # and includes its attributes.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Attribute>] all attribute definitions
      def collect_attributes(memo = [])
        if @node['ref']
          local, nsid = @node['ref'].split(':').reverse
          # When there's no prefix (nsid is nil), use the schema's target namespace
          namespace = nsid ? @node.namespaces["xmlns:#{nsid}"] : @schema[:target_namespace]

          attribute_group = @schemas.attribute_group(namespace, local)
          memo + attribute_group.attributes
        else
          super
        end
      end
    end

    # Represents xs:simpleContent for complex types with text-only content.
    #
    # Simple content types can have attributes but their content is
    # restricted to simple (text) values.
    #
    class SimpleContent < BaseType
      # Stop searching for attributes in simple content.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_attributes(memo = [])
        memo
      end

      # Stop searching for child elements in simple content.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end

    # Represents xs:annotation for documentation and app info.
    #
    # Annotations provide human-readable documentation and
    # application-specific information but don't affect the
    # type structure.
    #
    class Annotation < BaseType
      # Stop searching for attributes in annotations.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_attributes(memo = [])
        memo
      end

      # Stop searching for child elements in annotations.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end

    # Mapping of XSD element names to their corresponding Ruby classes.
    #
    # @return [Hash<String, Class>] element name to class mappings
    TYPE_MAPPING = {
      'attribute' => Attribute,
      'attributeGroup' => AttributeGroup,
      'element' => Element,
      'complexType' => ComplexType,
      'simpleType' => SimpleType,
      'simpleContent' => SimpleContent,
      'complexContent' => ComplexContent,
      'extension' => Extension,
      'restriction' => Restriction,
      'all' => All,
      'sequence' => Sequence,
      'choice' => Choice,
      'enumeration' => Enumeration,
      'annotation' => Annotation
    }.freeze

    # Builds an appropriate type object from an XSD node.
    #
    # Uses the {TYPE_MAPPING} to determine the correct class based on
    # the node's element name. Falls back to {AnyType} for unrecognized
    # elements.
    #
    # @param node [Nokogiri::XML::Node] the XSD element node
    # @param schemas [SchemaCollection] the schema collection for resolving references
    # @param schema [Hash] schema context information
    # @return [BaseType] an instance of the appropriate type class
    def self.build(node, schemas, schema = {})
      type_class(node).new(node, schemas, schema)
    end

    # Determines the appropriate class for an XSD node.
    #
    # @param node [Nokogiri::XML::Node] the XSD element node
    # @return [Class] the class to use for this node
    def self.type_class(node)
      type = node.name.split(':').last

      if TYPE_MAPPING.include? type
        TYPE_MAPPING[type]
      else
        logger.debug("No type mapping for #{type.inspect}. ")
        AnyType
      end
    end

    # Returns the logger instance for the XS module.
    #
    # @return [Logging::Logger] the logger instance
    def self.logger
      @logger ||= Logging.logger[self]
    end
  end
end
