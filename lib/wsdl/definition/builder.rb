# frozen_string_literal: true

require 'digest'

module WSDL
  class Definition
    # Constructs a frozen {Definition} from parsed WSDL data.
    #
    # Walks the parsed WSDL documents and schemas to enumerate all services,
    # ports, and operations. For each operation, resolves message references
    # and converts element trees to plain hashes via {XML::Element#to_definition_h}.
    #
    # @api private
    #
    class Builder
      # Schema version for serialized Definitions.
      # Bump when the internal hash structure changes.
      #
      # @return [Integer]
      SCHEMA_VERSION = 2

      # Empty message placeholder for operations whose element resolution fails.
      #
      # @return [Hash]
      EMPTY_MESSAGE = { header: [], body: [] }.freeze

      # Creates a new Builder.
      #
      # @param documents [Parser::DocumentCollection] parsed WSDL documents
      # @param schemas [Schema::Collection] parsed XML schemas
      # @param limits [Limits] resource limits
      # @param provenance [Array<Hash>] source provenance from import
      # @param schema_import_errors [Array<SchemaImportError>] recoverable schema import errors
      def initialize(documents:, schemas:, limits:, provenance:, schema_import_errors:)
        @documents = documents
        @schemas = schemas
        @limits = limits
        @provenance = provenance
        @schema_import_errors = schema_import_errors
      end

      # Builds and returns a frozen {Definition}.
      #
      # @return [Definition] the frozen definition
      def build
        @build_issues = []

        sources = @provenance.map(&:freeze).freeze
        services = build_services

        data = {
          schema_version: SCHEMA_VERSION,
          service_name: @documents.service_name,
          sources:,
          build_issues: @build_issues.freeze,
          services:,
          fingerprint: compute_fingerprint(sources)
        }

        Definition.new(data)
      end

      private

      # Builds the full services hash by walking documents.
      #
      # @return [Hash] nested service → port → operations structure # -- builds complete service tree
      def build_services
        services = {}

        @documents.services.each_value do |service|
          ports = {}

          service.ports.each_value do |port|
            operations = build_operations(port).freeze
            ports[port.name] = {
              type: port.type,
              endpoint: port.location,
              operations:
            }.freeze
          end

          services[service.name] = { ports: ports.freeze }.freeze
        end

        services.freeze
      end

      # Builds operations for a given port.
      #
      # Resolves binding and port_type once, then delegates each operation
      # to {#build_single_operation}.
      #
      # @param port [Parser::Port] the port
      # @return [Hash{String => Hash, Array<Hash>}] operation data keyed by name
      def build_operations(port)
        binding = port.fetch_binding(@documents)
        port_type = binding.fetch_port_type(@documents)
        operations = {}
        element_builder = XML::ElementBuilder.new(@schemas, limits: @limits, issues: @build_issues)

        binding.operations.to_a.each do |op_entry|
          metadata = build_single_operation(op_entry, binding, port_type, element_builder)
          store_operation(operations, op_entry[:name], metadata.freeze)
        end

        operations
      rescue UnresolvedReferenceError => e
        record_build_issue(nil, e.message)
        {}
      end

      # Builds a single operation's metadata hash.
      #
      # Resolves binding and port type operations, validates the port type
      # match, and populates the metadata from the resolved operation info.
      # Returns a default metadata hash when the port type operation is missing.
      #
      # @param op_entry [Hash] operation entry from {Parser::OperationMap#to_a}
      # @param binding [Parser::Binding] the resolved binding
      # @param port_type [Parser::PortType] the resolved port type
      # @param element_builder [XML::ElementBuilder] shared element builder
      # @return [Hash] operation metadata
      def build_single_operation(op_entry, binding, port_type, element_builder)
        op_name = op_entry[:name]
        metadata = default_operation(op_name, input_name: op_entry[:input_name])

        binding_op = binding.operations.fetch(op_name, input_name: op_entry[:input_name])
        port_type_op = port_type.operations.fetch(op_name, input_name: op_entry[:input_name]) { nil }

        unless port_type_op
          record_build_issue(op_name,
            "Binding operation #{op_name.inspect} not found in portType #{port_type.name.inspect}")
          return metadata
        end

        op_info = Parser::OperationInfo.new(
          op_name, binding_op, port_type_op,
          documents: @documents, schemas: @schemas,
          limits: @limits, issues: @build_issues,
          element_builder:
        )

        populate_operation_metadata(metadata, op_name, op_info)
        metadata
      end

      # Populates an operation metadata hash from resolved operation info.
      #
      # Sets SOAP protocol fields, binding styles, schema completeness,
      # and resolved input/output messages. All data is accessed through the
      # {Parser::OperationInfo} facade rather than reaching into lower-level
      # binding or port type objects directly.
      #
      # @param metadata [Hash] the operation metadata hash to populate
      # @param op_name [String] the operation name (for error reporting)
      # @param op_info [Parser::OperationInfo] the resolved operation info
      # @return [void]
      # rubocop:disable Metrics/AbcSize -- data-mapping method; high ABC from 9 hash assignments, not complexity
      def populate_operation_metadata(metadata, op_name, op_info)
        metadata[:soap_action] = op_info.soap_action
        metadata[:soap_version] = op_info.soap_version

        if op_info.input?
          metadata[:input_style] = op_info.input_style
          metadata[:output_style] = op_info.output_style
          metadata[:rpc_input_namespace] = op_info.rpc_input_namespace
          metadata[:rpc_output_namespace] = op_info.rpc_output_namespace
        else
          record_build_issue(op_name,
            "Binding operation #{op_name.inspect} is missing a required <input> element")
        end

        metadata[:schema_complete] = schema_complete_for_operation?(op_info)
        metadata[:input] = build_message(op_info.input)
        metadata[:output] = op_info.output ? build_message(op_info.output) : nil
      end
      # rubocop:enable Metrics/AbcSize

      # Returns an operation hash with safe defaults.
      #
      # Each field starts as nil/empty. {#build_single_operation} and
      # {#populate_operation_metadata} progressively enhance the hash
      # with binding-level metadata and resolved message data.
      #
      # @param name [String] the operation name
      # @param input_name [String, nil] disambiguator for overloaded operations
      # @return [Hash] operation data with nil/empty defaults
      def default_operation(name, input_name: nil)
        {
          name:, input_name:,
          soap_action: nil, soap_version: nil,
          input_style: nil, output_style: nil,
          rpc_input_namespace: nil, rpc_output_namespace: nil,
          schema_complete: false, input: EMPTY_MESSAGE, output: nil
        }
      end

      # Stores an operation in the operations hash, handling overloading.
      #
      # @param operations [Hash] the operations hash
      # @param name [String] the operation name
      # @param data [Hash] the operation data
      # @return [void]
      def store_operation(operations, name, data)
        if operations.key?(name)
          existing = operations[name]
          operations[name] = (existing.is_a?(Array) ? existing + [data] : [existing, data]).freeze
        else
          operations[name] = data
        end
      end

      # Converts message parts to plain hashes.
      #
      # @param message [Parser::Input, Parser::Output] the message parts
      # @return [Hash] message hash with header and body element hashes
      def build_message(message)
        {
          header: message.header_parts.map(&:to_definition_h).freeze,
          body: message.body_parts.map(&:to_definition_h).freeze
        }.freeze
      end

      # Records a build error issue.
      #
      # @param operation [String, nil] the operation name
      # @param error [String] description of the problem
      # @return [void]
      def record_build_issue(operation, error)
        @build_issues << { type: :build_error, operation:, error: }
      end

      # Returns whether schema metadata is complete for the given operation.
      #
      # In best-effort import mode, failures may be tolerated globally. This
      # method allows operation-level gating for strict request validation.
      #
      # @param operation_info [Parser::OperationInfo]
      # @return [Boolean]
      def schema_complete_for_operation?(operation_info)
        return true if @schema_import_errors.empty?
        return true if input_empty?(operation_info)
        return false if @schema_import_errors.any? { |error| error.base_location.nil? }

        operation_namespaces = input_namespaces_for(operation_info)
        return true if operation_namespaces.empty?

        affected_namespaces = namespaces_affected_by_import_errors
        !operation_namespaces.intersect?(affected_namespaces)
      end

      # @return [Boolean] true if the operation has no input parts
      def input_empty?(operation_info)
        input = operation_info.input
        input.header_parts.empty? && input.body_parts.empty?
      end

      # @return [Array<String>] namespaces used in operation input elements
      def input_namespaces_for(operation_info)
        elements = operation_info.input.header_parts + operation_info.input.body_parts
        namespaces = []
        elements.each do |element|
          collect_element_namespaces(element, namespaces)
        end
        namespaces.compact.uniq
      end

      # @return [void]
      def collect_element_namespaces(element, namespaces)
        namespaces << element.namespace
        element.children.each { |child| collect_element_namespaces(child, namespaces) }
      end

      # @return [Array<String>] namespaces whose schemas had import errors
      def namespaces_affected_by_import_errors
        error_bases = @schema_import_errors.filter_map(&:base_location).uniq

        @schemas.each_with_object([]) do |definition, memo|
          next unless error_bases.include?(definition.source_location)
          next unless definition.target_namespace

          memo << definition.target_namespace
        end.uniq
      end

      # Computes a deterministic fingerprint from source provenance.
      #
      # @param sources [Array<Hash>] provenance entries
      # @return [String] SHA-256 fingerprint
      def compute_fingerprint(sources)
        entries = sources.sort_by { |s| s[:location].to_s }.map { |source|
          "#{source[:location]}:#{source[:status]}:#{source[:digest] || source[:error]}"
        }

        "sha256:#{Digest::SHA256.hexdigest(entries.join("\n"))}"
      end
    end
  end
end
