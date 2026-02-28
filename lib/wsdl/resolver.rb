# frozen_string_literal: true

class WSDL
  # Resolves WSDL and schema locations to their XML content.
  #
  # This class handles three types of locations:
  # - HTTP/HTTPS URLs: Fetches the content via HTTP GET
  # - Raw XML strings: Returns the content as-is
  # - File paths: Reads the content from the local filesystem
  #
  # It also supports resolving relative paths against a base location,
  # which is essential for handling WSDL imports and XSD includes that
  # use relative schemaLocation attributes.
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
  # @example Resolving a relative path
  #   resolver = Resolver.new(http_adapter)
  #   xml = resolver.resolve('../common/types.xsd', base: '/path/to/wsdl/service.wsdl')
  #
  class Resolver
    # Pattern for matching HTTP/HTTPS URLs.
    URL_PATTERN = /^https?:/i

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
    # When a base location is provided and the location is relative,
    # the location is resolved against the base before fetching.
    #
    # @param location [String] a URL, file path, or raw XML string
    # @param base [String, nil] optional base location for resolving relative paths
    # @return [String] the XML content
    # @raise [Errno::ENOENT] if the file path does not exist
    def resolve(location, base: nil)
      absolute_location = resolve_location(location, base)
      fetch(absolute_location)
    end

    # Resolves a potentially relative location against a base location.
    #
    # If the location is already absolute (URL or absolute file path),
    # it is returned as-is. If it's relative and a base is provided,
    # it's resolved against that base.
    #
    # @param location [String] the location to resolve
    # @param base [String, nil] the base location
    # @return [String] the resolved absolute location
    def resolve_location(location, base = nil)
      # Raw XML is returned as-is
      return location if location =~ XML_PATTERN

      # Already absolute URL
      return location if location =~ URL_PATTERN

      # Already absolute file path
      return location if absolute_path?(location)

      # At this point, location is a relative file path
      # If no base is provided, resolve against current working directory
      # (this handles the initial WSDL being a relative path like "path/to/service.wsdl")
      return File.expand_path(location) if base.nil?

      # If base is inline XML, we can't resolve relative paths against it
      validate_base_for_relative!(location, base)

      # Resolve relative location against base
      resolve_relative(location, base)
    end

    # Checks if a location is relative (not absolute URL, not absolute path, not raw XML).
    #
    # @param location [String] the location to check
    # @return [Boolean] true if the location is relative
    def relative_location?(location)
      return false if location =~ XML_PATTERN
      return false if location =~ URL_PATTERN
      return false if absolute_path?(location)

      true
    end

    private

    # Validates that a valid base exists for resolving a relative location.
    #
    # This is called after checking for nil base (which is handled by expanding
    # against current directory), so it only checks for invalid bases like inline XML.
    #
    # @param location [String] the relative location
    # @param base [String] the base location (not nil at this point)
    # @raise [UnresolvableImportError] if the base is invalid for relative resolution
    def validate_base_for_relative!(location, base)
      return unless base =~ XML_PATTERN

      raise UnresolvableImportError,
            "Cannot resolve relative path #{location.inspect}: base is inline XML. " \
            'When loading WSDL from a string, all schema imports must use absolute URLs.'
    end

    # Fetches content from an absolute location.
    #
    # @param location [String] the absolute location (URL, file path, or raw XML)
    # @return [String] the content
    def fetch(location)
      case location
      when URL_PATTERN then @http.get(location)
      when XML_PATTERN then location
      else File.read(location)
      end
    end

    # Resolves a relative location against a base location.
    #
    # Handles both URL bases and file path bases.
    #
    # @param relative [String] the relative location
    # @param base [String] the base location
    # @return [String] the resolved absolute location
    def resolve_relative(relative, base)
      if base =~ URL_PATTERN
        resolve_relative_url(relative, base)
      else
        resolve_relative_path(relative, base)
      end
    end

    # Resolves a relative URL against a base URL.
    #
    # @param relative [String] the relative URL
    # @param base [String] the base URL
    # @return [String] the resolved absolute URL
    def resolve_relative_url(relative, base)
      base_uri = URI.parse(base)
      resolved = base_uri.merge(relative)
      resolved.to_s
    end

    # Resolves a relative file path against a base file path.
    #
    # @param relative [String] the relative file path
    # @param base [String] the base file path
    # @return [String] the resolved absolute file path
    def resolve_relative_path(relative, base)
      # Get the directory of the base file
      base_dir = File.dirname(base)

      # Join and normalize the path
      File.expand_path(relative, base_dir)
    end

    # Checks if a path is absolute.
    #
    # @param path [String] the path to check
    # @return [Boolean] true if the path is absolute
    def absolute_path?(path)
      # On Unix, absolute paths start with /
      # On Windows, they start with a drive letter (e.g., C:\)
      path.start_with?('/') || path.match?(/^[A-Za-z]:/)
    end
  end
end
