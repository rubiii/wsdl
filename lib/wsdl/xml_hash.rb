# frozen_string_literal: true

require 'nokogiri'

class WSDL
  # Converts XML documents to Ruby Hashes.
  # Simple replacement for the Nori library as we already use Nokogiri.
  #
  # This class provides a simple way to parse XML into nested Hashes
  # with symbolized, snake_case keys. Namespace prefixes are stripped
  # from element names.
  #
  # @example Basic usage
  #   xml = "<Envelope><Body><Result>42</Result></Body></Envelope>"
  #   hash = WSDL::XmlHash.parse(xml)
  #   # => { envelope: { body: { result: "42" } } }
  #
  # @example Parsing a Nokogiri document
  #   doc = Nokogiri::XML(xml)
  #   hash = WSDL::XmlHash.parse(doc)
  #
  class XmlHash
    # Parses XML into a Hash.
    #
    # @param xml [String, Nokogiri::XML::Document, Nokogiri::XML::Node]
    #   the XML to parse
    # @return [Hash] the parsed XML as a nested Hash
    def self.parse(xml)
      node = case xml
      when Nokogiri::XML::Document then xml.root
      when Nokogiri::XML::Node then xml
      else Nokogiri::XML(xml).root
      end

      instance = new
      key = instance.send(:to_snakecase, node.name).to_sym

      { key => instance.convert(node) }
    end

    # Converts an XML node to a Hash recursively.
    #
    # - Strips namespace prefixes from element names
    # - Converts element names to snake_case symbols
    # - Handles repeated elements by converting them to arrays
    # - Returns text content for leaf nodes
    #
    # @param node [Nokogiri::XML::Node] the XML node to convert
    # @return [Hash, String] the converted hash or text content
    def convert(node)
      children = node.element_children

      return node.text if children.empty?

      children.each_with_object({}) do |child, result|
        key = to_snakecase(child.name).to_sym
        value = convert(child)

        if result.key?(key)
          result[key] = [result[key]] unless result[key].is_a?(Array)
          result[key] << value
        else
          result[key] = value
        end
      end
    end

    private

    # Converts a string to snake_case.
    #
    # @param string [String] the string to convert
    # @return [String] the snake_case version
    # @example
    #   to_snakecase("GetUserResponse") # => "get_user_response"
    #   to_snakecase("XMLParser")       # => "xml_parser"
    #   to_snakecase("getHTTPResponse") # => "get_http_response"
    def to_snakecase(string)
      string
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr('-', '_')
        .downcase
    end
  end
end
