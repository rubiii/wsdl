# frozen_string_literal: true

module WSDL
  module TestService
    # Holds the parsed WSDL and operation response definitions for a test service.
    #
    # Created via {TestService.define} and retrieved via {TestService.[]}.
    # Each definition wraps a WSDL fixture, collects response matchers for
    # its operations, and can resolve operations through a cached {WSDL::Client}.
    #
    # @example
    #   service = WSDL::TestService[:blz_service]
    #   service.start
    #   service.wsdl_url  # => "http://127.0.0.1:12345/blz_service/?wsdl"
    #
    class ServiceDefinition
      # @return [Symbol] the registered name of this service
      attr_reader :name

      # @param name [Symbol] unique service name
      # @param wsdl_fixture [String] fixture path relative to spec/fixtures/
      def initialize(name:, wsdl_fixture:)
        @name = name
        @wsdl_fixture = wsdl_fixture
        @operations = {}
      end

      # Mounts this service on the shared {MockServer}.
      #
      # The server starts lazily on the first mount. Subsequent calls are no-ops.
      #
      # @return [void]
      def start
        MockServer.instance.mount(@name, self)
      end

      # Stops the shared {MockServer} (affects all services).
      #
      # @return [void]
      def stop
        MockServer.reset!
      end

      # Returns the WSDL URL for this service on the shared server.
      #
      # @return [String]
      # @raise [RuntimeError] if the service has not been started
      def wsdl_url
        MockServer.instance.wsdl_url(@name)
      end

      # Defines responses for a named operation using a DSL block.
      #
      # @param operation_name [Symbol] the WSDL operation name
      # @yield DSL block evaluated on an {OperationDefinition}
      # @return [void]
      def operation(operation_name, &)
        op_def = OperationDefinition.new(operation_name)
        op_def.instance_eval(&)
        @operations[operation_name] = op_def
      end

      # Validates all response and input definitions against the WSDL schemas.
      #
      # Called automatically by {TestService.define} after the DSL block runs.
      # Raises {ResponseDefinitionError} on any mismatch.
      #
      # @raise [ResponseDefinitionError] when a definition doesn't match the schema
      # @return [void]
      def validate_responses!
        @operations.each do |op_name, op_def|
          wsdl_operation = resolve_operation(op_name)
          input_elements = wsdl_operation.contract.request.body.elements
          output_elements = wsdl_operation.contract.response.body.elements
          op_def.validate!(op_name, input_elements:, output_elements:)
        end
      end

      # Finds a matching response for the given operation and parsed input hash.
      #
      # @param operation_name [Symbol] the operation name
      # @param input_hash [Hash] the parsed SOAP request body
      # @return [Hash, nil] the matching response hash, or nil if no match
      def find_response(operation_name, input_hash)
        op_def = @operations[operation_name]
        return nil unless op_def

        op_def.find_response(input_hash)
      end

      # Returns a cached {WSDL::Client} for this service's WSDL fixture.
      #
      # @return [WSDL::Client]
      def client
        @client ||= WSDL::Client.new(wsdl_path)
      end

      # Returns the absolute path to the WSDL fixture file.
      #
      # @return [String]
      def wsdl_path
        SpecSupport::Fixture.path(@wsdl_fixture)
      end

      # Returns the raw WSDL XML with endpoint URLs rewritten to the given base URL.
      #
      # @param base_url [String] the base URL to substitute (e.g. "http://127.0.0.1:1234/blz_service/")
      # @return [String] the rewritten WSDL XML
      def wsdl_xml(base_url)
        raw = File.read(wsdl_path)
        raw.gsub(/(?<=location=")[^"]+(?=")/, base_url)
      end

      # Returns operation names that have response definitions.
      #
      # @return [Array<Symbol>]
      def defined_operations
        @operations.keys
      end

      # Resolves a {WSDL::Operation} for the given operation name.
      #
      # Uses the first service and first port from the parsed WSDL.
      #
      # @param operation_name [Symbol] the operation name
      # @return [WSDL::Operation]
      def resolve_operation(operation_name)
        services = client.services
        service_name = services.keys.first
        ports = services[service_name][:ports]
        port_name = ports.keys.first
        client.operation(service_name, port_name, operation_name)
      end
    end
  end
end
