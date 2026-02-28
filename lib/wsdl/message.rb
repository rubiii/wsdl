# frozen_string_literal: true

require 'builder'

class WSDL
  # Builds XML message content for SOAP request headers and bodies.
  #
  # This class converts Ruby Hash data structures into XML elements
  # according to the WSDL-defined message parts. It handles both simple
  # and complex types, as well as singular and array values.
  #
  # @api private
  #
  class Message
    # Prefix used for attribute keys in the message hash.
    # Keys starting with this prefix are treated as XML attributes
    # rather than child elements.
    ATTRIBUTE_PREFIX = '_'

    # Creates a new Message builder.
    #
    # @param envelope [Envelope] the envelope instance for namespace registration
    # @param parts [Array<XML::Element>] the message part elements from the WSDL
    def initialize(envelope, parts)
      @logger = Logging.logger[self]

      @envelope = envelope
      @parts = parts
    end

    # Builds the XML message content from a Hash.
    #
    # @param message [Hash] the message data to convert to XML
    # @return [String] the XML string representation
    def build(message)
      builder = Builder::XmlMarkup.new(indent: 2, margin: 2)

      build_elements(@parts, message.dup, builder)
      builder.target!
    end

    private

    # Builds XML elements for a collection of element definitions.
    #
    # @param elements [Array<XML::Element>] the element definitions
    # @param message [Hash] the message data
    # @param xml [Builder::XmlMarkup] the XML builder
    # @return [void]
    def build_elements(elements, message, xml)
      elements.each do |element|
        name = element.name
        symbol_name = name.to_sym

        value = extract_value(name, symbol_name, message)

        if value == :unspecified
          @logger.debug("Skipping (optional?) element #{symbol_name.inspect} with no value.")
          next
        end

        tag = [symbol_name]

        if element.form == 'qualified'
          nsid = @envelope.register_namespace(element.namespace)
          tag.unshift(nsid)
        end

        if element.simple_type?
          build_simple_type_element(element, xml, tag, value)

        elsif element.complex_type?
          build_complex_type_element(element, xml, tag, value)

        end
      end
    end

    # Builds a simple type element (leaf node with text content).
    #
    # @param element [XML::Element] the element definition
    # @param xml [Builder::XmlMarkup] the XML builder
    # @param tag [Array] the tag name components (nsid and name)
    # @param value [Object] the value to render
    # @raise [ArgumentError] if the value type doesn't match the element cardinality
    # @return [void]
    def build_simple_type_element(element, xml, tag, value)
      if element.singular?
        raise ArgumentError, "Unexpected Array for the #{tag.last.inspect} simple type" if value.is_a? Array

        if value.is_a? Hash
          attributes, value = extract_attributes(value)
          xml.tag!(*tag, value[tag[1]], attributes)
        else
          xml.tag!(*tag, value)
        end
      else
        unless value.is_a? Array
          raise ArgumentError, "Expected an Array of values for the #{tag.last.inspect} simple type"
        end

        value.each do |val|
          xml.tag!(*tag, val)
        end
      end
    end

    # Builds a complex type element (element with child elements).
    #
    # @param element [XML::Element] the element definition
    # @param xml [Builder::XmlMarkup] the XML builder
    # @param tag [Array] the tag name components (nsid and name)
    # @param value [Hash, Array<Hash>] the value to render
    # @raise [ArgumentError] if the value type doesn't match the element cardinality
    # @return [void]
    def build_complex_type_element(element, xml, tag, value)
      if element.singular?
        raise ArgumentError, "Expected a Hash for the #{tag.last.inspect} complex type" unless value.is_a? Hash

        build_complex_tag(element, tag, value, xml)
      else
        unless value.is_a? Array
          raise ArgumentError, "Expected an Array of Hashes for the #{tag.last.inspect} complex type"
        end

        value.each do |val|
          build_complex_tag(element, tag, val, xml)
        end
      end
    end

    # Builds a complex type XML tag with its children.
    #
    # @param element [XML::Element] the element definition
    # @param tag [Array] the tag name components
    # @param value [Hash] the value hash
    # @param xml [Builder::XmlMarkup] the XML builder
    # @return [void]
    def build_complex_tag(element, tag, value, xml)
      attributes, value = extract_attributes(value)
      children = element.children

      if children.any?
        xml.tag!(*tag, attributes) do |xml|
          build_elements(children, value, xml)
        end
      elsif value && value[tag[1]]
        xml.tag!(*tag, value[tag[1]], attributes)
      else
        xml.tag!(*tag, attributes)
      end
    end

    # Extracts the value from the message by name or symbol_name.
    #
    # Respects nil values and returns a special symbol for actual missing values.
    # This allows distinguishing between "key not present" and "key present with nil value".
    #
    # @param name [String] the element name as a string
    # @param symbol_name [Symbol] the element name as a symbol
    # @param message [Hash] the message hash to extract from
    # @return [Object, :unspecified] the value, or :unspecified if the key is not present
    def extract_value(name, symbol_name, message)
      if message.include? name
        message[name]
      elsif message.include? symbol_name
        message[symbol_name]
      else
        :unspecified
      end
    end

    # Extracts XML attributes from a value hash.
    #
    # Keys that start with {ATTRIBUTE_PREFIX} are treated as XML attributes
    # and removed from the value hash. The prefix is stripped from the
    # attribute name.
    #
    # @param hash [Hash] the value hash to extract attributes from
    # @return [Array<Hash, Hash>] a tuple of [attributes, remaining_hash]
    # @example
    #   extract_attributes({ _id: "123", name: "test" })
    #   # => [{ "id" => "123" }, { name: "test" }]
    def extract_attributes(hash)
      attributes = {}

      hash.dup.each do |k, v|
        next unless k.to_s[0, 1] == ATTRIBUTE_PREFIX

        attributes[k.to_s[1..]] = v
        hash.delete(k)
      end

      [attributes, hash]
    end
  end
end
