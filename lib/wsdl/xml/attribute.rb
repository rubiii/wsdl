# frozen_string_literal: true

module WSDL
  module XML
    # Represents an XML attribute definition used for building SOAP messages.
    #
    # Attributes are defined on complex type elements and can be either
    # required or optional. They are rendered as XML attributes on the
    # parent element rather than as child elements.
    #
    # @api private
    #
    class Attribute
      def initialize
        @list = false
      end

      # @!attribute [rw] name
      #   The local name of this attribute.
      #   @return [String] the attribute name
      attr_accessor :name

      # @!attribute [rw] base_type
      #   The base type name for this attribute (e.g., 'xsd:string').
      #   @return [String] the base type name
      attr_accessor :base_type

      # @!attribute [rw] list
      #   Whether this attribute is an xs:list type (whitespace-separated values).
      #   @return [Boolean] true for list-derived simple types
      attr_accessor :list
      alias list? list

      # @!attribute [rw] use
      #   The use constraint for this attribute ('optional' or 'required').
      #   Defaults to 'optional' if not specified in the schema.
      #   @return [String] the use constraint
      attr_accessor :use

      # Returns whether this attribute is optional.
      #
      # @return [Boolean] true if the attribute use is 'optional'
      def optional?
        use == 'optional'
      end

      # Returns a hash representation of this attribute.
      #
      # Used by both Element#to_a (for paths) and PartContract (for tree)
      # to ensure consistent attribute metadata across introspection views.
      #
      # @return [Hash{Symbol => Object}] attribute metadata
      def to_h
        {
          name:,
          type: base_type,
          required: !optional?,
          list: list?
        }
      end

      # Returns a definition-oriented hash representation.
      #
      # This format preserves raw schema properties (base_type, use) rather than
      # derived properties (type, required), making it suitable for serialization
      # and round-trip reconstruction via {Definition::ElementHash}.
      #
      # @return [Hash{Symbol => Object}] definition-compatible attribute hash
      def to_definition_h
        {
          name:,
          base_type:,
          use:,
          list: list?
        }
      end

      # Compares two attributes by their properties.
      #
      # @param other [Object] the object to compare
      # @return [Boolean] true if attributes have identical properties
      def ==(other)
        return false unless other.is_a?(self.class)

        name == other.name &&
          base_type == other.base_type &&
          use == other.use &&
          list == other.list
      end

      alias eql? ==

      # @return [Integer] hash code based on attribute properties
      def hash
        [name, base_type, use, list].hash
      end
    end
  end
end
