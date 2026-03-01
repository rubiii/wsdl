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
  class Client
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
    #
    def initialize(wsdl, http: nil, pretty_print: true, cache: :default)
      @http = http || new_http_client
      @parser_result = load_parser_result(wsdl, cache)
      @pretty_print = pretty_print
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

    # Loads the parser result, using cache if available.
    #
    # @param wsdl [String] the WSDL location or content
    # @param cache [Cache, nil, Symbol] the cache to use (`:default` uses {WSDL.cache})
    # @return [Parser::Result] the parsed result
    #
    def load_parser_result(wsdl, cache)
      cache = WSDL.cache if cache == :default

      if cache
        cache.fetch(wsdl) { Parser::Result.new(wsdl, @http) }
      else
        Parser::Result.new(wsdl, @http)
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
