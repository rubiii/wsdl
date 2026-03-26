# frozen_string_literal: true

module WSDL
  # Wraps a {Definition} with an HTTP client for inspecting services
  # and executing SOAP operations.
  #
  # @example Basic usage
  #   definition = WSDL.parse('http://example.com/service?wsdl')
  #   client = WSDL::Client.new(definition)
  #   operation = client.operation('GetData')
  #
  # @example Calling an operation
  #   definition = WSDL.parse('http://example.com/service?wsdl')
  #   client = WSDL::Client.new(definition)
  #   operation = client.operation('GetData')
  #   operation.prepare do
  #     tag('GetData') { tag('id', 123) }
  #   end
  #   response = operation.invoke
  #
  # @example Multi-service WSDL
  #   client = WSDL::Client.new(definition)
  #   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
  #
  # @example With custom HTTP client
  #   client = WSDL::Client.new(definition, http: my_client)
  #
  # @example With runtime options
  #   config = WSDL::Config.new(strictness: WSDL::Strictness.off)
  #   client = WSDL::Client.new(definition, config:)
  #
  class Client
    # Creates a new Client instance from a pre-built {Definition}.
    #
    # Use {WSDL.parse} to create a Definition from a URL or file path.
    # Parse-time options (strictness, limits, sandbox_paths) belong on
    # {WSDL.parse}, not here.
    #
    # @param definition [Definition] a frozen {Definition} from {WSDL.parse} or {WSDL.load}
    # @param http [Object, nil] an optional HTTP client instance
    #   (defaults to a new instance of {WSDL.http_client})
    # @param config [Config, nil] runtime configuration for request validation
    #   and resource limits. Keyword arguments for {Config} options
    #   (e.g. +strictness:+, +limits:+) are also accepted directly
    #   and forwarded to {Config.new}.
    #
    # @raise [ArgumentError] if +definition+ is not a {Definition}
    #
    def initialize(definition, http: nil, config: nil, **)
      unless definition.is_a?(Definition)
        raise ArgumentError,
          "Client.new requires a Definition (got #{definition.class}). " \
          'Use WSDL.parse(source) to create one.'
      end

      @config = config ? config.with(**) : Config.new(**)
      @http = http || WSDL.http_client.new
      @definition = definition
    end

    # Returns the {Definition} for this client's WSDL.
    #
    # @return [Definition] the frozen definition
    attr_reader :definition

    # Returns the behavioral configuration for this client.
    #
    # @return [Config] the configuration instance
    #
    attr_reader :config

    # Returns the HTTP client's config for customizing timeouts, SSL, etc.
    #
    # @return [Object] the client configuration object
    #
    def http
      @http.config
    end

    # Returns the services and ports defined by the WSDL.
    #
    # Each port includes an +operations+ array. Overloaded operations
    # (same name, different messages) include +input_name+ for disambiguation.
    #
    # @return [Hash] a hash of service names to their port definitions
    #
    # @example
    #   client.services
    #   # => {"ServiceName" => {ports: {"PortName" => {type: "...", location: "...",
    #   #      operations: [{name: "Op1"}, {name: "Op2"}]}}}}
    #
    # rubocop:disable Metrics/AbcSize -- reconstructs legacy hash structure
    def services
      @services ||= definition.services.to_h { |svc|
        ports = definition.ports(svc[:name]).to_h { |port|
          port_soap_type = definition.port_type(svc[:name], port[:name])
          ops = definition.operations(svc[:name], port[:name]).map { |op|
            entry = { name: op[:name] }
            entry[:input_name] = op[:input_name] if op[:input_name]
            entry
          }
          [port[:name], { type: port_soap_type, location: port[:endpoint], operations: ops }]
        }
        [svc[:name], { ports: }]
      }
    end
    # rubocop:enable Metrics/AbcSize

    # Returns the name of the primary service defined by the WSDL.
    #
    # Falls back to the first discovered service key when the root
    # `definitions` element does not provide a `name` attribute.
    #
    # @return [String, nil] the service name, or nil if no service exists
    def service_name
      name = definition.service_name
      return name if name && !name.empty?

      definition.services.first&.dig(:name)
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
      verify_service_and_port!(service_name.to_s, port_name.to_s)
      definition.operations(service_name.to_s, port_name.to_s).map { |op| op[:name] }.uniq
    end

    # Returns an Operation instance for calling a SOAP operation.
    #
    # @overload operation(service_name, port_name, operation_name, input_name: nil)
    #   Returns an operation for the specified service, port, and operation.
    #   @param service_name [String, Symbol] the name of the service
    #   @param port_name [String, Symbol] the name of the port
    #   @param operation_name [String, Symbol] the name of the operation
    #   @param input_name [String, Symbol, nil] disambiguator for overloaded operations
    #
    # @overload operation(operation_name, input_name: nil)
    #   Returns an operation by name, auto-resolving the only service and port.
    #   Requires exactly one service with exactly one port.
    #   @param operation_name [String, Symbol] the name of the operation
    #   @param input_name [String, Symbol, nil] disambiguator for overloaded operations
    #
    # @return [Operation] the operation instance
    # @raise [ArgumentError] if the service, port, or operation does not exist,
    #   or if auto-resolution is used with multiple services/ports
    # @raise [UnsupportedStyleError] if the operation uses an unsupported style (e.g., rpc/encoded)
    # @raise [OperationOverloadError] if overloaded and strictness.operation_overloading is true
    #
    def operation(service_name_or_operation_name, port_name = nil, operation_name = nil, input_name: nil)
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

      build_operation_from_definition(service_name, port_name, operation_name, input_name:)
    end

    private

    # Validates that the given service and port exist in the Definition.
    #
    # @param service_name [String] service name
    # @param port_name [String] port name
    # @raise [ArgumentError] if service or port not found
    def verify_service_and_port!(service_name, port_name)
      svc = definition.services.find { |s| s[:name] == service_name }
      port = svc && svc[:ports].include?(port_name)

      return if port

      raise ArgumentError, "Unknown service #{service_name.inspect} or port #{port_name.inspect}.\n" \
                           "Here is a list of known services and port:\n#{services.inspect}"
    end

    # Builds an Operation from Definition data.
    #
    # @return [Operation]
    def build_operation_from_definition(service_name, port_name, operation_name, input_name: nil)
      defn = definition
      verify_overloading!(defn, service_name.to_s, port_name.to_s, operation_name.to_s)
      op_data = defn.operation_data(
        service_name.to_s, port_name.to_s, operation_name.to_s,
        input_name: input_name&.to_s
      )
      endpoint = defn.endpoint(service_name.to_s, port_name.to_s)

      verify_operation_style!(op_data)

      Operation.new(op_data, endpoint, @http, config: @config)
    end

    # Raises OperationOverloadError if the operation is overloaded and strict mode is enabled.
    #
    # @param defn [Definition] the definition
    # @param service [String] service name
    # @param port [String] port name
    # @param operation [String] operation name
    # @raise [OperationOverloadError] if overloaded and strictness.operation_overloading is true
    def verify_overloading!(defn, service, port, operation)
      return unless @config.strictness.operation_overloading

      ops = defn.operations(service, port).select { |op| op[:name] == operation }
      return unless ops.size > 1

      raise OperationOverloadError.new(
        "Operation #{operation.inspect} is overloaded #{ops.size} times. " \
        'Operation overloading is prohibited by WS-I Basic Profile R2304. ' \
        'To allow it, use: strictness: { operation_overloading: false }',
        operation_name: operation, port_type_name: port, overload_count: ops.size
      )
    end

    # Resolves service and port names, auto-detecting when there is exactly one of each.
    #
    # @param service_name [String, Symbol, nil] explicit service name, or nil to auto-resolve
    # @param port_name [String, Symbol, nil] explicit port name, or nil to auto-resolve
    # @return [Array(String, String)] the resolved service and port names
    # @raise [ArgumentError] if auto-resolution fails due to multiple services or ports
    def resolve_service_and_port(service_name, port_name)
      return [service_name, port_name] if service_name && port_name

      definition.resolve_service_and_port
    end

    # Raises if the operation style is not supported.
    #
    # @param op_data [Hash{Symbol => Object}] operation data hash
    # @raise [UnsupportedStyleError] if the operation style is not supported
    #
    def verify_operation_style!(op_data)
      return unless op_data[:input_style] == 'rpc/encoded'

      raise UnsupportedStyleError,
        "#{op_data[:name].inspect} is an #{op_data[:input_style].inspect} style operation.\n" \
        'Currently this style is not supported.'
    end
  end
end
