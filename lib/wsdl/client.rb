# frozen_string_literal: true

module WSDL
  # Main entry point for working with WSDL documents.
  #
  # This class provides a high-level interface for parsing WSDL documents,
  # inspecting services and operations, and executing SOAP requests.
  #
  # @example Basic usage
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   client.services
  #   # => {"ExampleService" => {ports: {"ExamplePort" => {type: "...", location: "..."}}}}
  #
  # @example Calling an operation
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
  #   operation.request do
  #     tag('GetData') { tag('id', 123) }
  #   end
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
  # @example Custom sandbox paths for local imports spanning multiple directories
  #   client = WSDL::Client.new('/path/to/service.wsdl',
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
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed.
    #   When nil (default), sandbox is determined automatically based on WSDL source:
    #   - URL source → file access disabled (all imports must use URLs)
    #   - Inline XML → file access disabled (all imports must use URLs)
    #   - File source → sandboxed to the WSDL's parent directory
    #   When provided, overrides the automatic sandbox with the specified directories.
    # @param limits [Limits, nil] resource limits for DoS protection.
    #   If nil, uses {WSDL.limits}. Use a custom Limits instance to increase
    #   limits for specific WSDLs that exceed defaults.
    # @param reject_doctype [Boolean] whether to reject XML documents containing
    #   DOCTYPE declarations (default: true). This is a defense-in-depth measure
    #   since legitimate SOAP/WSDL documents never require DOCTYPE. Set to false
    #   only for legacy systems that include DOCTYPE declarations.
    # @param strict_schema [Boolean] strict schema handling and request validation mode.
    #   - `true` (default) enables strict schema imports and strict request validation
    #   - `false` enables best-effort schema imports and relaxed request validation
    # @param max_request_elements [Integer, nil] max request AST elements (default: limits value)
    # @param max_request_depth [Integer, nil] max request AST nesting depth (default: limits value)
    # @param max_request_attributes [Integer, nil] max request AST attributes (default: limits value)
    #
    # rubocop:disable Metrics/ParameterLists
    def initialize(wsdl, http: nil, pretty_print: true, cache: :default, sandbox_paths: nil,
                   limits: nil, reject_doctype: true, strict_schema: true,
                   max_request_elements: nil, max_request_depth: nil, max_request_attributes: nil)
      # rubocop:enable Metrics/ParameterLists
      @http = http || WSDL.http_adapter.new
      @pretty_print = pretty_print
      @limits = limits || WSDL.limits
      @reject_doctype = reject_doctype
      @strict_schema = strict_schema ? true : false
      @request_limits = {
        max_request_elements: max_request_elements || @limits.max_request_elements,
        max_request_depth: max_request_depth || @limits.max_request_depth,
        max_request_attributes: max_request_attributes || @limits.max_request_attributes
      }.freeze

      validate_http_adapter!(@http)

      resolved_sandbox_paths = resolve_sandbox_paths(wsdl, sandbox_paths)
      @parser_result = load_parser_result(wsdl, cache, resolved_sandbox_paths)
    end

    # Returns whether pretty printing is enabled for XML output.
    #
    # @return [Boolean] true if XML will be formatted with indentation
    #
    attr_reader :pretty_print

    # Returns the resource limits used for parsing.
    #
    # @return [Limits] the limits instance
    #
    attr_reader :limits

    # Returns whether strict schema mode is enabled.
    #
    # @return [Boolean] strict schema mode
    attr_reader :strict_schema

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

    # Returns the name of the primary service defined by the WSDL.
    #
    # Falls back to the first discovered service key when the root
    # `definitions` element does not provide a `name` attribute.
    #
    # @return [String, nil] the service name, or nil if no service exists
    def service_name
      name = @parser_result.service_name
      return name if name && !name.empty?

      @parser_result.services.keys.first
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

      Operation.new(
        operation_info,
        @parser_result,
        @http,
        pretty_print:,
        strict_schema: @strict_schema,
        request_limits: @request_limits
      )
    end

    private

    # Resolves sandbox paths based on the WSDL source type.
    #
    # @param wsdl [String] the WSDL location or content
    # @param sandbox_paths [Array<String>, nil] explicit sandbox paths (overrides automatic detection)
    # @return [Array<String>, nil] resolved sandbox paths, or nil if file access is disabled
    #
    def resolve_sandbox_paths(wsdl, sandbox_paths)
      # If explicit sandbox_paths provided, use them
      return sandbox_paths if sandbox_paths

      # URL-loaded WSDLs and inline XML: disable file access entirely
      # All schema imports must use HTTP/HTTPS URLs
      return nil if wsdl.match?(URL_PATTERN) || wsdl.match?(XML_PATTERN)

      # File path: sandbox to the WSDL's parent directory
      # This prevents path traversal attacks while allowing imports within the same directory
      wsdl_directory = File.dirname(File.expand_path(wsdl))
      [wsdl_directory]
    end

    # Loads the parser result, using cache if available.
    #
    # @param wsdl [String] the WSDL location or content
    # @param cache [Cache, nil, Symbol] the cache to use (`:default` uses {WSDL.cache})
    # @param sandbox_paths [Array<String>, nil] the sandbox paths
    # @return [Parser::Result] the parsed result
    #
    def load_parser_result(wsdl, cache, sandbox_paths)
      Parser::CachedResult.load(
        wsdl:,
        http: @http,
        cache:,
        parse_options: {
          sandbox_paths:,
          limits: @limits,
          reject_doctype: @reject_doctype,
          strict_schema: @strict_schema
        }
      )
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

    # Validates that HTTP adapter satisfies required cache contract.
    #
    # @param adapter [Object] HTTP adapter instance
    # @raise [InvalidHTTPAdapterError] if the adapter does not expose a usable cache_key
    #
    def validate_http_adapter!(adapter)
      unless adapter.respond_to?(:cache_key)
        raise InvalidHTTPAdapterError,
              "HTTP adapter #{adapter.class.name} must implement #cache_key for parser cache partitioning."
      end

      cache_key = adapter.cache_key
      return if cache_key && !cache_key.to_s.empty?

      raise InvalidHTTPAdapterError,
            "HTTP adapter #{adapter.class.name} must return a non-empty #cache_key."
    end
  end
end
