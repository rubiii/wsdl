# frozen_string_literal: true

module WSDL
  class Definition
    # Collects unique namespace URIs from a services hash and replaces
    # them with integer indices for compact serialization.
    #
    # @example
    #   namespaces, compacted_services = NamespaceCompactor.call(services)
    #
    # @api private
    #
    class NamespaceCompactor
      # Collects and compacts namespace URIs in a single pass.
      #
      # @param services [Hash] the built services hash (with URI strings)
      # @return [Array(Array<String>, Hash)] namespace table and compacted services
      def self.call(services)
        new(services).call
      end

      # @param services [Hash] the built services hash
      def initialize(services)
        @services = services
      end

      # @return [Array(Array<String>, Hash)] namespace table and compacted services
      def call
        namespaces = collect_uris
        ns_map = namespaces.each_with_index.to_h
        compacted = compact_services(ns_map)

        [namespaces.freeze, compacted]
      end

      private

      # Collects unique namespace URIs in first-occurrence order.
      #
      # @return [Array<String>] unique namespace URIs
      def collect_uris
        uris = []
        seen = {}

        @services.each_value do |svc_data|
          svc_data['ports'].each_value do |port|
            record(uris, seen, port['type'])
            port['operations'].each_value do |op_or_ops|
              ops = op_or_ops.is_a?(Array) ? op_or_ops : [op_or_ops]
              ops.each { |operation| collect_operation(uris, seen, operation) }
            end
          end
        end

        uris
      end

      # @return [void]
      def collect_operation(uris, seen, operation)
        record(uris, seen, operation['rpc_input_namespace'])
        record(uris, seen, operation['rpc_output_namespace'])
        collect_message(uris, seen, operation['input']) if operation['input']
        collect_message(uris, seen, operation['output']) if operation['output']
      end

      # @return [void]
      def collect_message(uris, seen, message)
        (message['header'] + message['body']).each do |element|
          collect_element(uris, seen, element)
        end
      end

      # @return [void]
      def collect_element(uris, seen, element)
        record(uris, seen, element['ns'])
        element['children']&.each { |child| collect_element(uris, seen, child) }
      end

      # @return [void]
      def record(uris, seen, uri)
        return unless uri
        return if seen.key?(uri)

        seen[uri] = true
        uris << uri
      end

      # Replaces namespace URI strings with integer indices.
      #
      # @param ns_map [Hash{String => Integer}] URI to index mapping
      # @return [Hash] new services hash with integer namespace indices
      def compact_services(ns_map)
        @services.transform_values { |svc_data|
          {
            'ports' => svc_data['ports'].transform_values { |port|
              compact_port(port, ns_map)
            }.freeze
          }.freeze
        }.freeze
      end

      # @return [Hash] port with namespace values replaced by indices
      def compact_port(port, ns_map)
        result = port.dup
        result['type'] = ns_map.fetch(port['type']) if port['type']
        result['operations'] = port['operations'].transform_values { |entry|
          if entry.is_a?(Array)
            entry.map { |operation| compact_operation(operation, ns_map) }.freeze
          else
            compact_operation(entry, ns_map)
          end
        }.freeze
        result.freeze
      end

      # @return [Hash] operation with namespace values replaced by indices
      def compact_operation(operation, ns_map)
        result = operation.dup
        %w[rpc_input_namespace rpc_output_namespace].each do |key|
          result[key] = ns_map.fetch(operation[key]) if operation[key]
        end
        result['input'] = compact_message(operation['input'], ns_map) if operation['input']
        result['output'] = compact_message(operation['output'], ns_map) if operation['output']
        result.freeze
      end

      # @return [Hash] message with element namespace values replaced by indices
      def compact_message(message, ns_map)
        {
          'header' => message['header'].map { |element| compact_element(element, ns_map) }.freeze,
          'body' => message['body'].map { |element| compact_element(element, ns_map) }.freeze
        }.freeze
      end

      # @return [Hash] element with 'ns' replaced by index (recursive)
      def compact_element(element, ns_map)
        result = element.dup
        result['ns'] = ns_map.fetch(element['ns']) if element['ns']
        result['children'] = element['children'].map { |c| compact_element(c, ns_map) }.freeze if element['children']
        result.freeze
      end
    end
  end
end
