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
  # @example Calling an operation (single service/port WSDL)
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   operation = client.operation('GetData')
  #   operation.prepare do
  #     tag('GetData') { tag('id', 123) }
  #   end
  #   response = operation.invoke
  #
  # @example Calling an operation (multi-service WSDL)
  #   client = WSDL::Client.new('http://example.com/service?wsdl')
  #   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
  #
  # @example With custom HTTP adapter
  #   client = WSDL::Client.new('http://example.com/service?wsdl', http: my_adapter)
  #
  # @example Disable XML formatting for whitespace-sensitive servers
  #   client = WSDL::Client.new('http://example.com/service?wsdl', format_xml: false)
  #
  # @example Disable caching for this instance
  #   client = WSDL::Client.new('http://example.com/service?wsdl', cache: false)
  #
  # @example Custom sandbox paths for local imports spanning multiple directories
  #   client = WSDL::Client.new('/path/to/service.wsdl',
  #                             sandbox_paths: ['/path/to', '/other/schemas'])
  #
  # @example Reusable configuration
  #   config = WSDL::Config.new(format_xml: false, strict_schema: false)
  #   client = WSDL::Client.new('http://example.com/service?wsdl', config:)
  #
  class Client
    # Creates a new Client instance.
    #
    # Behavioral options (format_xml, strict_schema, sandbox_paths,
    # limits) can be passed as keyword arguments or
    # grouped into a {Config} object via the `config:` parameter.
    # When both are provided, keyword arguments take precedence.
    #
    # @param wsdl [String] a URL or file path to the WSDL document
    # @param http [Object, nil] an optional HTTP adapter instance
    #   (defaults to a new instance of {WSDL.http_adapter})
    # @param cache [Cache, nil, false] the cache to use for parsed definitions.
    #   Use `nil` (default) to use {WSDL.cache}, or `false` to disable caching.
    # @param config [Config, nil] a reusable {Config} instance grouping behavioral
    #   options. Any keyword arguments for Config options override the config object.
    #   Additional keyword arguments are forwarded to {Config#initialize}.
    #   See {Config#initialize} for the full list of supported options.
    #
    def initialize(wsdl, http: nil, cache: nil, config: nil, **)
      @config = config ? config.with(**) : Config.new(**)

      source = Source.validate_wsdl!(wsdl)
      @http = http || WSDL.http_adapter.new

      validate_http_adapter!(@http)

      resolved_sandbox_paths = source.resolve_sandbox_paths(@config.sandbox_paths)
      @parser_result = Parser::CachedResult.load(
        wsdl:,
        http: @http,
        cache:,
        parse_options: ParseOptions.new(
          sandbox_paths: resolved_sandbox_paths,
          limits: @config.limits,
          strict_schema: @config.strict_schema
        )
      )
    end

    # Returns the behavioral configuration for this client.
    #
    # @return [Config] the configuration instance
    #
    attr_reader :config

    # Returns the HTTP adapter's config for customizing timeouts, SSL, etc.
    #
    # @return [Object] the adapter configuration object
    #
    def http
      @http.config
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
    # @overload operations(service_name, port_name)
    #   Returns operations for the specified service and port.
    #   @param service_name [String, Symbol] the name of the service
    #   @param port_name [String, Symbol] the name of the port
    #
    # @overload operations
    #   Returns operations for the only service and port.
    #   Requires exactly one service with exactly one port.
    #
    # @return [Array<String>] the list of operation names
    # @raise [ArgumentError] if the service or port does not exist,
    #   or if auto-resolution is used with multiple services/ports
    #
    def operations(service_name = nil, port_name = nil)
      if service_name && !port_name
        raise ArgumentError, 'Pass 0 arguments (auto-resolve) or 2 arguments (service_name, port_name).'
      end

      service_name, port_name = resolve_service_and_port(service_name, port_name)
      @parser_result.operations(service_name.to_s, port_name.to_s)
    end

    # Returns an Operation instance for calling a SOAP operation.
    #
    # @overload operation(service_name, port_name, operation_name)
    #   Returns an operation for the specified service, port, and operation.
    #   @param service_name [String, Symbol] the name of the service
    #   @param port_name [String, Symbol] the name of the port
    #   @param operation_name [String, Symbol] the name of the operation
    #
    # @overload operation(operation_name)
    #   Returns an operation by name, auto-resolving the only service and port.
    #   Requires exactly one service with exactly one port.
    #   @param operation_name [String, Symbol] the name of the operation
    #
    # @return [Operation] the operation instance
    # @raise [ArgumentError] if the service, port, or operation does not exist,
    #   or if auto-resolution is used with multiple services/ports
    # @raise [UnsupportedStyleError] if the operation uses an unsupported style (e.g., rpc/encoded)
    #
    def operation(service_name_or_operation_name, port_name = nil, operation_name = nil)
      if port_name && !operation_name
        raise ArgumentError,
              'Pass 1 argument (operation_name) or 3 arguments (service_name, port_name, operation_name).'
      end

      if operation_name
        service_name = service_name_or_operation_name
      else
        operation_name = service_name_or_operation_name
        service_name, port_name = resolve_service_and_port(nil, nil)
      end

      operation_info = @parser_result.operation(service_name.to_s, port_name.to_s, operation_name.to_s)
      verify_operation_style!(operation_info)

      Operation.new(
        operation_info,
        @parser_result,
        @http,
        config: @config
      )
    end

    private

    # Resolves service and port names, auto-detecting when there is exactly one of each.
    #
    # @param service_name [String, Symbol, nil] explicit service name, or nil to auto-resolve
    # @param port_name [String, Symbol, nil] explicit port name, or nil to auto-resolve
    # @return [Array(String, String)] the resolved service and port names
    # @raise [ArgumentError] if auto-resolution fails due to multiple services or ports
    def resolve_service_and_port(service_name, port_name)
      return [service_name, port_name] if service_name && port_name

      svcs = services
      resolved_service = resolve_single_service(svcs)
      resolved_port = resolve_single_port(resolved_service, svcs)

      [resolved_service, resolved_port]
    end

    # @param svcs [Hash] the services hash from {#services}
    # @return [String] the single service name
    # @raise [ArgumentError] if there are zero or multiple services
    #
    def resolve_single_service(svcs)
      return svcs.keys.first if svcs.size == 1

      names = svcs.keys.map(&:inspect).join(', ')
      raise ArgumentError, "Cannot auto-resolve service: expected 1, found #{svcs.size} (#{names}). " \
                           'Pass explicit service and port names.'
    end

    # @param resolved_service [String] the resolved service name
    # @param svcs [Hash] the services hash from {#services}
    # @return [String] the single port name
    # @raise [ArgumentError] if there are zero or multiple ports
    #
    def resolve_single_port(resolved_service, svcs)
      ports = svcs[resolved_service][:ports]
      return ports.keys.first if ports.size == 1

      names = ports.keys.map(&:inspect).join(', ')
      raise ArgumentError, "Cannot auto-resolve port for service #{resolved_service.inspect}: " \
                           "expected 1, found #{ports.size} (#{names}). " \
                           'Pass explicit service and port names.'
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
