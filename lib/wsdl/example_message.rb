# frozen_string_literal: true

class WSDL
  # Builds example message Hashes from WSDL message part definitions.
  #
  # This class generates template Hash structures that match the expected
  # format for SOAP request headers and bodies. The generated hashes use
  # type names as placeholder values, making it easy to see what data
  # structure is expected and fill in actual values.
  #
  # @api private
  #
  # @example Building an example message
  #   parts = operation.input.body_parts
  #   example = ExampleMessage.build(parts)
  #   # => { user: { name: "string", age: "int" } }
  #
  class ExampleMessage
    # Builds an example message Hash from message part elements.
    #
    # Recursively processes the element tree, creating a nested Hash
    # structure that mirrors the expected XML message format. Simple
    # types use their base type name as a placeholder value, while
    # complex types become nested Hashes.
    #
    # @param parts [Array<XML::Element>] the message part elements
    # @return [Hash] an example message hash with placeholder values
    #
    # @example Simple type result
    #   # For a simple string element named "name"
    #   # => { name: "string" }
    #
    # @example Complex type result
    #   # For a complex element "user" with children
    #   # => { user: { name: "string", age: "int" } }
    #
    # @example Array element result
    #   # For a repeating element "items"
    #   # => { items: [{ name: "string" }] }
    #
    # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity -- straightforward recursive builder, splitting would hurt readability
    def self.build(parts)
      memo = {}

      parts.each do |element|
        name = element.name.to_sym

        if element.simple_type?
          base_type_local = element.base_type.split(':').last
          base_type_local = [base_type_local] unless element.singular?
          memo[name] = base_type_local

        elsif element.complex_type?
          value = build(element.children)

          value.merge! collect_attributes(element) unless element.attributes.empty?

          # Indicate that arbitrary content is allowed via xs:any
          value.merge! any_content_placeholder if element.any_content?

          value = [value] unless element.singular?
          memo[name] = value

        end
      end

      memo
    end
    # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    # Returns a placeholder hash indicating xs:any wildcard content.
    #
    # This placeholder shows users that the element accepts arbitrary
    # XML content beyond the explicitly defined schema elements.
    #
    # @return [Hash] a placeholder indicating any content is allowed
    #
    # @example
    #   # => { :"(any)" => "arbitrary XML content allowed" }
    #
    def self.any_content_placeholder
      { '(any)': 'arbitrary XML content allowed' }
    end

    # Collects attributes from an element and formats them for the example hash.
    #
    # Attribute keys are prefixed with an underscore to distinguish them
    # from child elements when building the actual XML message.
    #
    # @param element [XML::Element] the element to collect attributes from
    # @return [Hash] a hash of attribute names (prefixed with '_') to their base types
    #
    # @example
    #   # For an element with id and type attributes
    #   # => { _id: "string", _type: "QName" }
    #
    def self.collect_attributes(element)
      element.attributes.to_h do |attribute|
        [:"_#{attribute.name}", attribute.base_type]
      end
    end
  end
end
