# frozen_string_literal: true

class WSDL
  class XML
    # Represents an XML attribute definition used for building SOAP messages.
    #
    # Attributes are defined on complex type elements and can be either
    # required or optional. They are rendered as XML attributes on the
    # parent element rather than as child elements.
    #
    # @api private
    #
    class Attribute
      # @!attribute [rw] name
      #   The local name of this attribute.
      #   @return [String] the attribute name
      attr_accessor :name

      # @!attribute [rw] base_type
      #   The base type name for this attribute (e.g., 'xsd:string').
      #   @return [String] the base type name
      attr_accessor :base_type

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
    end
  end
end
