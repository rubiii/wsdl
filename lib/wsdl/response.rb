# frozen_string_literal: true

require 'nori'

class WSDL
  # Represents a SOAP response from an operation call.
  #
  # This class wraps the raw HTTP response and provides methods
  # for parsing and accessing the SOAP envelope contents.
  #
  # @example Accessing the response body
  #   response = operation.call
  #   puts response.body[:get_user_response][:user][:name]
  #
  # @example Working with the raw response
  #   response = operation.call
  #   puts response.raw  # Raw XML string
  #
  # @example Using XPath queries
  #   response = operation.call
  #   users = response.xpath('//ns:User', 'ns' => 'http://example.com/users')
  #   users.each { |user| puts user.text }
  #
  class Response
    # Creates a new Response instance.
    #
    # @param raw_response [String] the raw HTTP response body (XML)
    def initialize(raw_response)
      @raw_response = raw_response
    end

    # Returns the raw XML response string.
    #
    # @return [String] the raw XML response body
    def raw
      @raw_response
    end

    # Returns the parsed SOAP body as a Hash.
    #
    # The body is extracted from the SOAP envelope and returned
    # with symbolized, snake_case keys.
    #
    # @return [Hash] the parsed body content
    # @example
    #   response.body
    #   # => { get_user_response: { user: { name: "John", age: 30 } } }
    def body
      hash[:envelope][:body]
    end
    alias to_hash body

    # Returns the parsed SOAP header as a Hash.
    #
    # The header is extracted from the SOAP envelope and returned
    # with symbolized, snake_case keys.
    #
    # @return [Hash, nil] the parsed header content, or nil if empty
    def header
      hash[:envelope][:header]
    end

    # Returns the entire parsed SOAP envelope as a Hash.
    #
    # Keys are symbolized and converted to snake_case.
    #
    # @return [Hash] the complete parsed envelope
    def hash
      @hash ||= nori.parse(raw)
    end

    # Returns the response as a Nokogiri XML document.
    #
    # Use this when you need full XML manipulation capabilities
    # or want to run XPath queries.
    #
    # @return [Nokogiri::XML::Document] the parsed XML document
    def doc
      @doc ||= Nokogiri.XML(raw)
    end

    # Executes an XPath query on the response document.
    #
    # @param path [String] the XPath expression
    # @param namespaces [Hash, nil] optional namespace mappings
    #   (defaults to the namespaces declared in the document)
    # @return [Nokogiri::XML::NodeSet] the matching nodes
    # @example Without custom namespaces
    #   response.xpath('//User')
    # @example With custom namespaces
    #   response.xpath('//ns:User', 'ns' => 'http://example.com/users')
    def xpath(path, namespaces = nil)
      doc.xpath(path, namespaces || xml_namespaces)
    end

    # Returns all XML namespaces declared in the response document.
    #
    # This is useful for building XPath queries that need to
    # reference namespaced elements.
    #
    # @return [Hash<String, String>] namespace prefix to URI mappings
    # @example
    #   response.xml_namespaces
    #   # => { "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
    #   #      "xmlns:ns1" => "http://example.com/users" }
    def xml_namespaces
      @xml_namespaces ||= doc.collect_namespaces
    end

    private

    # Returns a configured Nori parser instance.
    #
    # @return [Nori] the parser configured for SOAP responses
    def nori
      return @nori if @nori

      nori_options = {
        strip_namespaces: true,
        convert_tags_to: ->(tag) { tag.snakecase.to_sym }
      }

      non_nil_nori_options = nori_options.compact
      @nori = Nori.new(non_nil_nori_options)
    end
  end
end
