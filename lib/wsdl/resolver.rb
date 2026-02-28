# frozen_string_literal: true

class WSDL
  # Resolves WSDL and schema locations to their XML content.
  #
  # This class handles three types of locations:
  # - HTTP/HTTPS URLs: Fetches the content via HTTP GET
  # - Raw XML strings: Returns the content as-is
  # - File paths: Reads the content from the local filesystem
  #
  # @example Resolving a URL
  #   resolver = Resolver.new(http_adapter)
  #   xml = resolver.resolve('http://example.com/service?wsdl')
  #
  # @example Resolving a local file
  #   resolver = Resolver.new(http_adapter)
  #   xml = resolver.resolve('/path/to/service.wsdl')
  #
  # @example Resolving raw XML
  #   resolver = Resolver.new(http_adapter)
  #   xml = resolver.resolve('<definitions>...</definitions>')
  #
  class Resolver
    # Pattern for matching HTTP/HTTPS URLs.
    URL_PATTERN = /^https?:/

    # Pattern for matching raw XML content (starts with '<').
    XML_PATTERN = /^</

    # Creates a new Resolver instance.
    #
    # @param http [Object] an HTTP adapter instance that responds to `get(url)`
    def initialize(http)
      @http = http
    end

    # Resolves a location to its XML content.
    #
    # @param location [String] a URL, file path, or raw XML string
    # @return [String] the XML content
    # @raise [Errno::ENOENT] if the file path does not exist
    def resolve(location)
      case location
      when URL_PATTERN then @http.get(location)
      when XML_PATTERN then location
      else File.read(location)
      end
    end
  end
end
