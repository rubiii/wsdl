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
          name: name,
          type: base_type,
          required: !optional?,
          list: list?
        }
      end
    end
  end
end
