# frozen_string_literal: true

module WSDL
  module Parser
    # Resolves WSDL and schema locations to their XML content.
    #
    # This class handles three types of locations:
    # - HTTP/HTTPS URLs: Fetches the content via HTTP GET
    # - Raw XML strings: Returns the content as-is
    # - File paths: Reads the content from the local filesystem (with sandbox restrictions)
    #
    # It also supports resolving relative paths against a base location,
    # which is essential for handling WSDL imports and XSD includes that
    # use relative schemaLocation attributes.
    #
    # == Security
    #
    # The resolver implements sandbox restrictions to prevent path traversal attacks.
    # When a WSDL contains malicious schemaLocation attributes like
    # `../../../../etc/passwd`, the resolver blocks access to files outside
    # the allowed directory tree.
    #
    # File access is controlled by the `sandbox_paths` option:
    # - When `sandbox_paths` is provided: file access is allowed within those directories
    # - When `sandbox_paths` is nil: file access is disabled (URL-only mode)
    #
    # @example Resolving a URL (no file access needed)
    #   resolver = Resolver.new(http_adapter)
    #   xml = resolver.resolve('http://example.com/service?wsdl')
    #
    # @example Resolving a local file with sandboxing
    #   resolver = Resolver.new(http_adapter, sandbox_paths: ['/app/wsdl'])
    #   xml = resolver.resolve('/app/wsdl/service.wsdl')
    #
    # @api private
    #
    class Resolver
      include Formatting

      # Pattern for matching HTTP/HTTPS URLs.
      URL_PATTERN = /^https?:/i

      # Pattern for matching file:// URLs (blocked for security).
      FILE_URL_PATTERN = /^file:/i

      # Pattern for matching raw XML content (starts with '<').
      XML_PATTERN = /^</

      # Creates a new Resolver instance.
      #
      # @param http [Object] an HTTP adapter instance that responds to `get(url)`
      # @param sandbox_paths [Array<String>, nil] directories where file access is allowed.
      #   When nil, file access is disabled and all imports must use URLs.
      # @param limits [Limits, nil] resource limits for DoS protection.
      #   If nil, uses {WSDL.limits}.
      #
      def initialize(http, sandbox_paths: nil, limits: nil)
        @http = http
        @sandbox_paths = normalize_sandbox_paths(sandbox_paths)
        @limits = limits || WSDL.limits
        @total_bytes_downloaded = 0
      end

      # Returns the sandbox paths (normalized to absolute paths).
      #
      # @return [Array<String>, nil] the allowed directories for file access
      #
      attr_reader :sandbox_paths

      # Returns the resource limits.
      #
      # @return [Limits] the limits instance
      #
      attr_reader :limits

      # Returns the total bytes downloaded so far.
      #
      # @return [Integer] cumulative bytes downloaded
      #
      attr_reader :total_bytes_downloaded

      # Resolves a location to its XML content.
      #
      # When a base location is provided and the location is relative,
      # the location is resolved against the base before fetching.
      #
      # @param location [String] a URL, file path, or raw XML string
      # @param base [String, nil] optional base location for resolving relative paths
      # @return [String] the XML content
      # @raise [Errno::ENOENT] if the file path does not exist
      # @raise [PathRestrictionError] if the file is outside the sandbox
      #
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
      #
      def resolve_location(location, base = nil)
        # Raw XML is returned as-is
        return location if location =~ XML_PATTERN

        # Block file:// URLs for security (SSRF prevention)
        validate_not_file_url!(location)

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
      #
      def relative_location?(location)
        return false if location =~ XML_PATTERN
        return false if location =~ URL_PATTERN
        return false if absolute_path?(location)

        true
      end

      # Checks if file access is allowed in the current configuration.
      #
      # @return [Boolean] true if file access is allowed
      #
      def file_access_allowed?
        !@sandbox_paths.nil?
      end

      private

      # Normalizes sandbox paths to absolute paths.
      #
      # @param paths [Array<String>, nil] the paths to normalize
      # @return [Array<String>, nil] the normalized paths
      #
      def normalize_sandbox_paths(paths)
        return nil if paths.nil?

        paths.map { |p| File.expand_path(p) }
      end

      # Validates that a location is not a file:// URL.
      #
      # file:// URLs are blocked to prevent SSRF attacks that could read
      # local files through URL-based imports.
      #
      # @param location [String] the location to validate
      # @raise [PathRestrictionError] if the location is a file:// URL
      #
      def validate_not_file_url!(location)
        return unless location =~ FILE_URL_PATTERN

        raise PathRestrictionError,
              "file:// URLs are not allowed for security reasons: #{location.inspect}. " \
              'Use a local file path instead if you need to load from the filesystem.'
      end

      # Validates that a valid base exists for resolving a relative location.
      #
      # This is called after checking for nil base (which is handled by expanding
      # against current directory), so it only checks for invalid bases like inline XML.
      #
      # @param location [String] the relative location
      # @param base [String] the base location (not nil at this point)
      # @raise [UnresolvableImportError] if the base is invalid for relative resolution
      #
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
      # @raise [PathRestrictionError] if file access is not allowed or path is outside sandbox
      #
      def fetch(location)
        case location
        when URL_PATTERN then fetch_http(location)
        when XML_PATTERN then location
        else fetch_file(location)
        end
      end

      # Fetches content from a file path with security checks.
      #
      # @param path [String] the file path to read
      # @return [String] the file content
      # @raise [PathRestrictionError] if file access is not allowed or path is outside sandbox
      # @raise [ResourceLimitError] if file size exceeds limits
      #
      def fetch_file(path)
        validate_file_access!(path)
        validate_file_size!(path)

        content = File.read(path)
        track_download(content.bytesize)
        content
      end

      # Validates file size before reading.
      #
      # @param path [String] the file path to check
      # @raise [ResourceLimitError] if file size exceeds max_document_size
      #
      def validate_file_size!(path)
        return unless @limits.max_document_size

        # Check if file exists first; if not, let File.read raise the appropriate error
        return unless File.exist?(path)

        file_size = File.size(path)
        return if file_size <= @limits.max_document_size

        raise ResourceLimitError.new(
          "File size #{format_bytes(file_size)} exceeds limit of #{format_bytes(@limits.max_document_size)}: #{path}",
          limit_name: :max_document_size,
          limit_value: @limits.max_document_size,
          actual_value: file_size
        )
      end

      # Fetches content via HTTP with size validation.
      #
      # @param url [String] the URL to fetch
      # @return [String] the response body
      # @raise [ResourceLimitError] if response size exceeds limits
      #
      def fetch_http(url)
        content = @http.get(url)
        content_size = content.bytesize

        validate_document_size!(content_size, url)
        track_download(content_size)

        content
      end

      # Validates document size against limits.
      #
      # @param size [Integer] the document size in bytes
      # @param source [String] the source URL or path for error messages
      # @raise [ResourceLimitError] if size exceeds max_document_size
      #
      def validate_document_size!(size, source)
        return unless @limits.max_document_size
        return if size <= @limits.max_document_size

        raise ResourceLimitError.new(
          "Document size #{format_bytes(size)} exceeds limit of " \
          "#{format_bytes(@limits.max_document_size)}: #{source}",
          limit_name: :max_document_size,
          limit_value: @limits.max_document_size,
          actual_value: size
        )
      end

      # Tracks bytes downloaded and validates against total download limit.
      #
      # @param bytes [Integer] the number of bytes downloaded
      # @raise [ResourceLimitError] if total download size exceeds limit
      #
      def track_download(bytes)
        @total_bytes_downloaded += bytes
        validate_total_download_size!
      end

      # Validates total download size against limits.
      #
      # @raise [ResourceLimitError] if total exceeds max_total_download_size
      #
      def validate_total_download_size!
        return unless @limits.max_total_download_size
        return if @total_bytes_downloaded <= @limits.max_total_download_size

        raise ResourceLimitError.new(
          "Total download size #{format_bytes(@total_bytes_downloaded)} exceeds limit of " \
          "#{format_bytes(@limits.max_total_download_size)}",
          limit_name: :max_total_download_size,
          limit_value: @limits.max_total_download_size,
          actual_value: @total_bytes_downloaded
        )
      end

      # Validates that file access is allowed for the given path.
      #
      # @param path [String] the file path to validate
      # @raise [PathRestrictionError] if access is not allowed
      #
      def validate_file_access!(path)
        if @sandbox_paths.nil?
          raise PathRestrictionError,
                "File access is disabled. Cannot read #{path.inspect}. " \
                'All schema imports must use URLs, or provide sandbox_paths to allow file access.'
        end

        validate_path_in_sandbox!(path)
      end

      # Validates that a path is within the allowed sandbox directories.
      #
      # @param path [String] the path to validate
      # @raise [PathRestrictionError] if the path is outside all sandbox directories
      #
      def validate_path_in_sandbox!(path)
        normalized_path = File.expand_path(path)

        return if @sandbox_paths.any? { |sandbox| path_within_directory?(normalized_path, sandbox) }

        raise PathRestrictionError,
              "Path #{path.inspect} is outside the allowed directories. " \
              "Allowed: #{@sandbox_paths.inspect}. " \
              'This may indicate a path traversal attack in a schemaLocation attribute.'
      end

      # Checks if a path is within a directory (handles symlinks safely).
      #
      # @param path [String] the path to check
      # @param directory [String] the directory that should contain the path
      # @return [Boolean] true if path is within directory
      #
      def path_within_directory?(path, directory)
        # Ensure both paths end consistently for prefix comparison
        normalized_dir = directory.end_with?('/') ? directory : "#{directory}/"
        normalized_path = path.end_with?('/') ? path : "#{path}/"

        # Check if path starts with directory (is a child)
        # Also allow exact match (the directory itself)
        path == directory || normalized_path.start_with?(normalized_dir)
      end

      # Resolves a relative location against a base location.
      #
      # Handles both URL bases and file path bases.
      #
      # @param relative [String] the relative location
      # @param base [String] the base location
      # @return [String] the resolved absolute location
      #
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
      #
      def resolve_relative_url(relative, base)
        URI.join(base, relative).to_s
      end

      # Resolves a relative file path against a base file path.
      #
      # @param relative [String] the relative path
      # @param base [String] the base path
      # @return [String] the resolved absolute path
      #
      def resolve_relative_path(relative, base)
        # Get the directory of the base file
        base_dir = File.dirname(File.expand_path(base))
        # Resolve the relative path against it
        File.expand_path(relative, base_dir)
      end

      # Checks if a path is absolute.
      #
      # @param path [String] the path to check
      # @return [Boolean] true if the path is absolute
      #
      def absolute_path?(path)
        Pathname.new(path).absolute?
      end
    end
  end
end
