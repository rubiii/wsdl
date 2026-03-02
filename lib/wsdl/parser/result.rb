# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a parsed WSDL document definition.
    #
    # This class is responsible for importing and parsing WSDL documents,
    # including all referenced schemas and imports. It provides access to
    # services, ports, and operations defined in the WSDL.
    #
    # This is the main result object produced by the parsing process and
    # is used internally by {WSDL::Client} to access WSDL information.
    #
    # @example Accessing services (URL-loaded, no file access)
    #   result = Parser::Result.new('http://example.com/service?wsdl', http)
    #   result.services
    #   # => {"ServiceName" => {ports: {"PortName" => {type: "...", location: "..."}}}}
    #
    # @example Loading from file with sandbox
    #   result = Parser::Result.new('/app/wsdl/service.wsdl', http,
    #                               sandbox_paths: ['/app/wsdl'])
    #
    # @example Getting operation names
    #   operations = result.operations('ServiceName', 'PortName')
    #   # => ["GetUser", "CreateUser", "DeleteUser"]
    #
    # @api private
    #
    class Result
      # Pattern for matching HTTP/HTTPS URLs.
      URL_PATTERN = /^https?:/i

      # Pattern for matching raw XML content (starts with '<').
      XML_PATTERN = /^</

      # Creates a new Result by importing and parsing a WSDL document.
      #
      # @param wsdl [String] a URL, file path, or raw XML string of the WSDL document
      # @param http [Object] an HTTP adapter instance for fetching remote documents
      # @param sandbox_paths [Array<String>, nil, Symbol] directories where file access is allowed.
      #   - `:auto` (default) — Automatically determine based on WSDL source:
      #     - URL/inline XML → file access disabled
      #     - File path → sandboxed to WSDL's parent directory
      #   - `Array<String>` — Use the specified directories as the sandbox
      #   - `nil` — Disable file access entirely
      # @param limits [Limits, nil] resource limits for DoS protection.
      #   If nil, uses {WSDL.limits}.
      # @param reject_doctype [Boolean] whether to reject XML with DOCTYPE declarations
      #   (default: true). This is a defense-in-depth security measure.
      # @param schema_imports [Symbol] schema import failure policy:
      #   - `:best_effort` (default) — log and skip non-security schema import failures
      #   - `:strict` — raise non-security schema import failures as {SchemaImportError}
      #   Fatal errors (for example, {PathRestrictionError}) always raise.
      #
      # rubocop:disable Metrics/ParameterLists
      def initialize(wsdl, http, sandbox_paths: :auto, limits: nil, reject_doctype: true, schema_imports: :best_effort)
        # rubocop:enable Metrics/ParameterLists
        @documents = DocumentCollection.new
        @schemas = Schema::Collection.new
        @limits = limits || WSDL.limits
        @schema_imports = schema_imports

        resolved_sandbox_paths = resolve_sandbox_paths(wsdl, sandbox_paths)
        resolver = Resolver.new(http, sandbox_paths: resolved_sandbox_paths, limits: @limits)
        importer = Importer.new(
          resolver,
          @documents,
          @schemas,
          limits: @limits,
          reject_doctype:,
          schema_imports: @schema_imports
        )
        importer.import(wsdl)
      end

      # The collection of parsed WSDL documents.
      #
      # @return [DocumentCollection] the document collection
      attr_reader :documents

      # The collection of XML schemas referenced by the WSDL.
      #
      # @return [Schema::Collection] the schema collection
      attr_reader :schemas

      # The resource limits used for parsing.
      #
      # @return [Limits] the limits instance
      attr_reader :limits

      # The schema import failure policy used while parsing.
      #
      # @return [Symbol] schema import policy (`:best_effort` or `:strict`)
      attr_reader :schema_imports

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
      #   result.services
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
        verify_service_and_port_exist!(service_name, port_name)

        port = @documents.service_port(service_name, port_name)
        binding = port.fetch_binding(@documents)

        binding.operations.keys
      end

      # Returns an OperationInfo for a given service, port, and operation name.
      #
      # @param service_name [String] the name of the service
      # @param port_name [String] the name of the port
      # @param operation_name [String] the name of the operation
      # @return [OperationInfo] the operation info instance
      # @raise [ArgumentError] if the service, port, or operation does not exist
      def operation(service_name, port_name, operation_name)
        verify_operation_exists!(service_name, port_name, operation_name)

        port = @documents.service_port(service_name, port_name)
        endpoint = port.location

        binding = port.fetch_binding(@documents)
        binding_operation = binding.operations.fetch(operation_name)

        port_type = binding.fetch_port_type(@documents)
        port_type_operation = port_type.operations.fetch(operation_name)

        OperationInfo.new(operation_name, endpoint, binding_operation, port_type_operation, self)
      end

      private

      # Raises a useful error if the operation does not exist.
      #
      # @param service_name [String] the name of the service
      # @param port_name [String] the name of the port
      # @param operation_name [String] the name of the operation
      # @raise [ArgumentError] if the operation does not exist
      def verify_operation_exists!(service_name, port_name, operation_name)
        ops = operations(service_name, port_name)

        return if ops.include? operation_name

        raise ArgumentError, "Unknown operation #{operation_name.inspect} for " \
                             "service #{service_name.inspect} and port #{port_name.inspect}.\n" \
                             "You may want to try one of #{ops.inspect}."
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

      # Resolves sandbox paths based on the WSDL source type.
      #
      # @param wsdl [String] the WSDL location or content
      # @param sandbox_paths [Symbol, Array<String>, nil] explicit sandbox paths or :auto
      # @return [Array<String>, nil] resolved sandbox paths, or nil if file access is disabled
      #
      def resolve_sandbox_paths(wsdl, sandbox_paths)
        # If explicit sandbox_paths provided (not :auto), use them as-is
        return sandbox_paths unless sandbox_paths == :auto

        # URL-loaded WSDLs and inline XML: disable file access entirely
        return nil if wsdl.match?(URL_PATTERN) || wsdl.match?(XML_PATTERN)

        # File path: sandbox to the WSDL's parent directory
        wsdl_directory = File.dirname(File.expand_path(wsdl))
        [wsdl_directory]
      end
    end
  end
end
