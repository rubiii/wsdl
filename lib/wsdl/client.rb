# frozen_string_literal: true

module WSDL
  # Configuration for file access when resolving schema imports.
  #
  # @!attribute [r] mode
  #   @return [Symbol] the file access mode (:sandbox, :disabled, :unrestricted)
  # @!attribute [r] sandbox_paths
  #   @return [Array<String>, nil] directories where file access is allowed
  #
  FileAccessConfig = Data.define(:mode, :sandbox_paths)

  # Main entry point for working with WSDL documents.
  #
  # This class provides a high-level interface for parsing WSDL documents,
  # inspecting services and operations, and executing SOAP requests.
  #
  # == Security
  #
  # By default, the client applies sandbox restrictions to prevent path traversal
  # attacks in schema imports:
  #
  # - **URL-loaded WSDLs** — File access is disabled; all schema imports must use URLs
  # - **File-loaded WSDLs** — File access is sandboxed to the WSDL's directory tree
  #
  # This prevents malicious schemaLocation attributes from reading arbitrary system files.
  #
  # @example Basic usage
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   client.services
  #   # => {"ExampleService" => {ports: {"ExamplePort" => {type: "...", location: "..."}}}}
  #
  # @example Calling an operation
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
  #   operation.body = { id: 123 }
  #   response = operation.call
  #
  # @example With custom HTTP adapter
  #   client = WSDL::Client.new('http://example.com/service?wsdl', http: my_adapter)
  #
  # @example Disable pretty printing for whitespace-sensitive servers
  #   client = WSDL::Client.new('http://example.com/service?wsdl', pretty_print: false)
  #
  # @example Disable caching for this instance
  #   client = WSDL::Client.new('http://example.com/service?wsdl', cache: nil)
  #
  # @example Custom file access (use with caution)
  #   client = WSDL::Client.new('/path/to/service.wsdl',
  #                             file_access: :sandbox,
  #                             sandbox_paths: ['/path/to', '/other/schemas'])
  #
  class Client
    # Pattern for matching HTTP/HTTPS URLs.
    URL_PATTERN = /^https?:/i

    # Pattern for matching raw XML content (starts with '<').
    XML_PATTERN = /^</

    # Creates a new Client instance.
    #
    # @param wsdl [String] a URL, file path, or raw XML string of the WSDL document
    # @param http [Object, nil] an optional HTTP adapter instance
    #   (defaults to a new instance of {WSDL.http_adapter})
    # @param pretty_print [Boolean] whether to format XML output with indentation
    #   and margins. Set to `false` for whitespace-sensitive SOAP servers.
    #   Defaults to `true`.
    # @param cache [Cache, nil, Symbol] the cache to use for parsed definitions.
    #   Use `:default` to use {WSDL.cache}, or `nil` to disable caching.
    #   Defaults to {WSDL.cache}. Pass `nil` to disable caching for this instance.
    # @param file_access [Symbol] controls file access for schema imports:
    #   - `:auto` — Automatically determine based on WSDL source (default):
    #     - URL source → file access disabled (all imports must use URLs)
    #     - Inline XML → file access disabled (no base path available)
    #     - File source → unrestricted (local files are trusted)
    #   - `:sandbox` — Allow file access only within `sandbox_paths`
    #   - `:disabled` — No file access at all (URL-only mode)
    #   - `:unrestricted` — No restrictions (default for file-loaded WSDLs)
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed.
    #   Only used when `file_access` is `:sandbox`.
    #
    # rubocop:disable Metrics/ParameterLists
    def initialize(wsdl, http: nil, pretty_print: true, cache: :default, file_access: :auto, sandbox_paths: nil)
      # rubocop:enable Metrics/ParameterLists
      @http = http || new_http_client
      @pretty_print = pretty_print

      config = resolve_file_access_options(wsdl, file_access, sandbox_paths)
      @parser_result = load_parser_result(wsdl, cache, config.mode, config.sandbox_paths)
    end

    # Returns the Parser::Result instance containing parsed WSDL data.
    #
    # @return [Parser::Result] the parsed WSDL result
    #
    # @api private
    #
    attr_reader :parser_result

    # Returns whether pretty printing is enabled for XML output.
    #
    # @return [Boolean] true if XML will be formatted with indentation
    #
    attr_reader :pretty_print

    # Returns the HTTP adapter's client instance for configuration.
    #
    # @return [Object] the underlying HTTP client
    #
    def http
      @http.client
    end

    # Returns the services and ports defined by the WSDL.
    #
    # @return [Hash] a hash of service names to their port definitions
    #
    # @example
    #   client.services
    #   # => {"ServiceName" => {ports: {"PortName" => {type: "...", location: "..."}}}}
    #
    def services
      @parser_result.services
    end

    # Returns an array of operation names for a service and port.
    #
    # @param service_name [String, Symbol] the name of the service
    # @param port_name [String, Symbol] the name of the port
    # @return [Array<String>] the list of operation names
    # @raise [ArgumentError] if the service or port does not exist
    #
    def operations(service_name, port_name)
      @parser_result.operations(service_name.to_s, port_name.to_s)
    end

    # Returns an Operation instance for calling a SOAP operation.
    #
    # @param service_name [String, Symbol] the name of the service
    # @param port_name [String, Symbol] the name of the port
    # @param operation_name [String, Symbol] the name of the operation
    # @return [Operation] the operation instance
    # @raise [ArgumentError] if the service, port, or operation does not exist
    # @raise [UnsupportedStyleError] if the operation uses an unsupported style (e.g., rpc/encoded)
    #
    def operation(service_name, port_name, operation_name)
      operation_info = @parser_result.operation(service_name.to_s, port_name.to_s, operation_name.to_s)
      verify_operation_style!(operation_info)

      Operation.new(operation_info, @parser_result, @http, pretty_print:)
    end

    private

    # Resolves file access options based on the WSDL source type.
    #
    # @param wsdl [String] the WSDL location or content
    # @param file_access [Symbol] the requested file access mode
    # @param sandbox_paths [Array<String>, nil] explicit sandbox paths
    # @return [FileAccessConfig] resolved file access configuration
    #
    def resolve_file_access_options(wsdl, file_access, sandbox_paths)
      return FileAccessConfig.new(mode: file_access, sandbox_paths:) unless file_access == :auto

      # URL-loaded WSDLs and inline XML: disable file access entirely
      # All schema imports must use HTTP/HTTPS URLs
      if wsdl.match?(URL_PATTERN) || wsdl.match?(XML_PATTERN)
        return FileAccessConfig.new(mode: :disabled, sandbox_paths: nil)
      end

      # File path: trust local files (user controls the WSDL source)
      # Users who want tighter controls can use explicit :sandbox mode
      FileAccessConfig.new(mode: :unrestricted, sandbox_paths: nil)
    end

    # Loads the parser result, using cache if available.
    #
    # @param wsdl [String] the WSDL location or content
    # @param cache [Cache, nil, Symbol] the cache to use (`:default` uses {WSDL.cache})
    # @param file_access [Symbol] the file access mode
    # @param sandbox_paths [Array<String>, nil] the sandbox paths
    # @return [Parser::Result] the parsed result
    #
    def load_parser_result(wsdl, cache, file_access, sandbox_paths)
      cache = WSDL.cache if cache == :default

      if cache
        cache.fetch(wsdl) { Parser::Result.new(wsdl, @http, file_access:, sandbox_paths:) }
      else
        Parser::Result.new(wsdl, @http, file_access:, sandbox_paths:)
      end
    end

    # Returns a new instance of the HTTP adapter.
    #
    # @return [Object] a new HTTP adapter instance
    #
    def new_http_client
      WSDL.http_adapter.new
    end

    # Raises if the operation style is not supported.
    #
    # @param operation_info [Parser::OperationInfo] the operation to verify
    # @raise [UnsupportedStyleError] if the operation style is not supported
    #
    def verify_operation_style!(operation_info)
      return unless operation_info.input_style == 'rpc/encoded'

      raise UnsupportedStyleError,
            "#{operation_info.name.inspect} is an #{operation_info.input_style.inspect} style operation.\n" \
            'Currently this style is not supported.'
    end
  end
end
