# frozen_string_literal: true

require_relative 'test_service/response_matcher'
require_relative 'test_service/input_extractor'
require_relative 'test_service/operation_definition'
require_relative 'test_service/service_definition'
require_relative 'test_service/mock_server'

module WSDL
  # Internal test infrastructure for running mock SOAP services backed by real WSDLs.
  #
  # Each integration spec defines its service inline at the top of the file.
  # Responses are validated against the WSDL schema at definition time.
  # The shared {MockServer} provides a single WEBrick instance for
  # full round-trip integration testing.
  #
  # @example Defining a service
  #   WSDL::TestService.define(:blz_service, wsdl: 'wsdl/blz_service') do
  #     operation :getBank do
  #       on blz: '70070010' do
  #         { details: { bezeichnung: 'Deutsche Bank' } }
  #       end
  #     end
  #   end
  #
  # @example Using in a test
  #   let(:service) { WSDL::TestService[:blz_service] }
  #   subject(:client) { WSDL::Client.new(service.wsdl_url) }
  #
  module TestService
    # Raised when a response or input definition doesn't match the WSDL schema.
    class ResponseDefinitionError < StandardError; end

    @registry = {}

    class << self
      # Defines a named test service with response definitions.
      #
      # The block is evaluated on a {ServiceDefinition} instance.
      # All response and input definitions are validated against the
      # WSDL schema before the service is registered.
      #
      # @param name [Symbol] unique service name
      # @param wsdl [String] fixture path relative to spec/fixtures/
      # @yield DSL block evaluated on {ServiceDefinition}
      # @raise [ResponseDefinitionError] when definitions don't match the schema
      # @return [void]
      def define(name, wsdl:, &)
        definition = ServiceDefinition.new(name:, wsdl_fixture: wsdl)
        definition.instance_eval(&)
        definition.validate_responses!
        @registry[name] = definition
      end

      # Retrieves a defined service by name.
      #
      # @param name [Symbol] the service name
      # @return [ServiceDefinition]
      # @raise [ArgumentError] when the service is not defined
      def [](name)
        @registry.fetch(name) do
          raise ArgumentError, "Unknown test service #{name.inspect}. " \
                               "Defined services: #{@registry.keys.inspect}"
        end
      end

      # Resets the registry and stops the shared server.
      #
      # @return [void]
      def reset!
        @registry.clear
        MockServer.reset!
      end
    end
  end
end
