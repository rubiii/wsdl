# frozen_string_literal: true

require 'wsdl/definition/operation'
require 'wsdl/definition/document_collection'
require 'wsdl/xs/schema_collection'
require 'wsdl/resolver'
require 'wsdl/importer'

class WSDL
  # Represents a parsed WSDL document definition.
  #
  # This class is responsible for importing and parsing WSDL documents,
  # including all referenced schemas and imports. It provides access to
  # services, ports, and operations defined in the WSDL.
  #
  # @example Accessing services
  #   definition = WSDL::Definition.new('http://example.com/service?wsdl', http)
  #   definition.services
  #   # => {"ServiceName" => {ports: {"PortName" => {type: "...", location: "..."}}}}
  #
  # @example Getting operation names
  #   operations = definition.operations('ServiceName', 'PortName')
  #   # => ["GetUser", "CreateUser", "DeleteUser"]
  #
  class Definition
    # Creates a new Definition by importing and parsing a WSDL document.
    #
    # @param wsdl [String] a URL, file path, or raw XML string of the WSDL document
    # @param http [Object] an HTTP adapter instance for fetching remote documents
    def initialize(wsdl, http)
      @documents = Definition::DocumentCollection.new
      @schemas = XS::SchemaCollection.new

      resolver = Resolver.new(http)
      importer = Importer.new(resolver, @documents, @schemas)
      importer.import(wsdl)
    end

    # The collection of parsed WSDL documents.
    #
    # @return [DocumentCollection] the document collection
    attr_reader :documents

    # The collection of XML schemas referenced by the WSDL.
    #
    # @return [XS::SchemaCollection] the schema collection
    attr_reader :schemas

    # Returns the name of the primary service.
    #
    # This is the name attribute of the root WSDL definitions element.
    #
    # @return [String] the service name
    def service_name
      @documents.service_name
    end

    # Returns a Hash of services and ports defined by the WSDL.
    #
    # @return [Hash] a hash mapping service names to their port definitions
    # @example
    #   definition.services
    #   # => {
    #   #      "UserService" => {
    #   #        ports: {
    #   #          "UserServicePort" => {
    #   #            type: "http://schemas.xmlsoap.org/wsdl/soap/",
    #   #            location: "http://example.com/UserService"
    #   #          }
    #   #        }
    #   #      }
    #   #    }
    def services
      @documents.services.values.inject({}) { |memo, service| memo.merge service.to_hash }
    end

    # Returns an array of operation names for a given service and port.
    #
    # @param service_name [String] the name of the service
    # @param port_name [String] the name of the port
    # @return [Array<String>] the list of operation names
    # @raise [ArgumentError] if the service or port does not exist
    def operations(service_name, port_name)
      verify_service_and_port_exist! service_name, port_name

      port = @documents.service_port(service_name, port_name)
      binding = port.fetch_binding(@documents)

      binding.operations.keys
    end

    # Returns an Operation for a given service, port, and operation name.
    #
    # @param service_name [String] the name of the service
    # @param port_name [String] the name of the port
    # @param operation_name [String] the name of the operation
    # @return [Operation] the operation instance
    # @raise [ArgumentError] if the service, port, or operation does not exist
    def operation(service_name, port_name, operation_name)
      verify_operation_exists! service_name, port_name, operation_name

      port = @documents.service_port(service_name, port_name)
      endpoint = port.location

      binding = port.fetch_binding(@documents)
      binding_operation = binding.operations.fetch(operation_name)

      port_type = binding.fetch_port_type(@documents)
      port_type_operation = port_type.operations.fetch(operation_name)

      Operation.new(operation_name, endpoint, binding_operation, port_type_operation, self)
    end

    private

    # Raises a useful error if the operation does not exist.
    #
    # @param service_name [String] the name of the service
    # @param port_name [String] the name of the port
    # @param operation_name [String] the name of the operation
    # @raise [ArgumentError] if the operation does not exist
    def verify_operation_exists!(service_name, port_name, operation_name)
      operations = operations(service_name, port_name)

      return if operations.include? operation_name

      raise ArgumentError, "Unknown operation #{operation_name.inspect} for " \
                           "service #{service_name.inspect} and port #{port_name.inspect}.\n" \
                           "You may want to try one of #{operations.inspect}."
    end

    # Raises a useful error if the service or port does not exist.
    #
    # @param service_name [String] the name of the service
    # @param port_name [String] the name of the port
    # @raise [ArgumentError] if the service or port does not exist
    def verify_service_and_port_exist!(service_name, port_name)
      service = services[service_name]
      port = service[:ports][port_name] if service

      return if port

      raise ArgumentError, "Unknown service #{service_name.inspect} or port #{port_name.inspect}.\n" \
                           "Here is a list of known services and port:\n" + services.inspect
    end
  end
end
