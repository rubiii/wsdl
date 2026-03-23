# frozen_string_literal: true

require 'digest'
require 'json'

module WSDL
  class Definition
    # Constructs a frozen {Definition} from a {Parser::Result}.
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
      SCHEMA_VERSION = 1

      # Creates a new Builder.
      #
      # @param parser_result [Parser::Result] the parsed WSDL result
      def initialize(parser_result)
        @result = parser_result
      end

      # Builds and returns a frozen {Definition}.
      #
      # @return [Definition] the frozen definition
      def build
        data = {
          schema_version: SCHEMA_VERSION,
          service_name: @result.service_name,
          sources: @result.provenance.dup,
          services: build_services
        }

        data[:fingerprint] = compute_fingerprint(data[:sources])

        Definition.new(data)
      end

      private

      # Builds the full services hash by walking documents.
      #
      # @return [Hash] nested service → port → operations structure # -- builds complete service tree
      def build_services
        services = {}

        @result.documents.services.each_value do |service|
          ports = {}

          service.ports.each_value do |port|
            operations = build_operations(service.name, port)
            ports[port.name] = {
              type: port.type,
              endpoint: port.location,
              operations: operations
            }
          end

          services[service.name] = { ports: ports }
        end

        services
      end

      # Builds operations for a given port.
      #
      # @param service_name [String] the service name
      # @param port [Parser::Port] the port
      # @return [Hash{String => Hash, Array<Hash>}] operation data keyed by name
      def build_operations(service_name, port)
        binding = port.fetch_binding(@result.documents)
        operations = {}

        binding.operations.to_a.each do |op_entry|
          op_name = op_entry[:name]
          input_name = op_entry[:input_name]

          op_data = build_operation(service_name, port, op_name, input_name:)
          store_operation(operations, op_name, op_data)
        end

        operations
      rescue UnresolvedReferenceError
        {}
      end

      # Builds a single operation's data hash.
      #
      # @param service_name [String] the service name
      # @param port [Parser::Port] the port
      # @param op_name [String] the operation name
      # @param input_name [String, nil] disambiguator for overloaded operations
      # @return [Hash] the operation data # -- collects all operation metadata
      def build_operation(service_name, port, op_name, input_name: nil)
        op_info = @result.operation(service_name, port.name, op_name, input_name:)

        {
          name: op_name,
          input_name: input_name,
          soap_action: op_info.soap_action,
          soap_version: op_info.soap_version,
          input_style: op_info.input_style,
          output_style: op_info.output_style,
          rpc_input_namespace: op_info.binding_operation.input_body[:namespace],
          rpc_output_namespace: op_info.binding_operation.output_body[:namespace],
          schema_complete: @result.schema_complete_for_operation?(op_info),
          input: build_message(op_info.input),
          output: op_info.output ? build_message(op_info.output) : nil
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
          operations[name] = existing.is_a?(Array) ? existing + [data] : [existing, data]
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
          header: message.header_parts.map(&:to_definition_h),
          body: message.body_parts.map(&:to_definition_h)
        }
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
