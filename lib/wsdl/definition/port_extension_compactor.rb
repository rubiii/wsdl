# frozen_string_literal: true

module WSDL
  class Definition
    # Detects ports within the same service that have identical operations
    # and replaces duplicates with an +extends+ reference to the base port.
    #
    # The first port with a given set of operations becomes the "base".
    # Subsequent ports with +==+-identical operations replace their
    # +operations+ key with an +extends+ string pointing to the base port
    # name. All other keys (+endpoint+, +type+, +defaults+) are preserved.
    #
    # Runs after {DefaultsCompactor} in the Builder pipeline. Extension is
    # scoped per-service — ports in different services are never compared.
    #
    # @example
    #   services = PortExtensionCompactor.call(services)
    #
    # @api private
    #
    class PortExtensionCompactor
      # Compacts duplicate ports into base + extends references.
      #
      # @param services [Hash] the services hash (post-defaults-compaction)
      # @return [Hash] compacted services hash with extends references
      def self.call(services)
        new(services).call
      end

      # @param services [Hash] the services hash (post-defaults-compaction)
      def initialize(services)
        @services = services
      end

      # Walks all services and replaces duplicate ports with extends references.
      #
      # @return [Hash] compacted services hash
      def call
        compact_services
      end

      private

      # Compacts all services by detecting port extensions.
      #
      # @return [Hash] new services hash with extends references
      def compact_services
        @services.transform_values { |svc_data|
          { 'ports' => compact_ports(svc_data['ports']).freeze }.freeze
        }.freeze
      end

      # Compacts ports within a single service.
      #
      # Iterates ports in insertion order. The first port with a given
      # operations hash becomes the base. Later ports with identical
      # operations get their +operations+ key replaced with +extends+.
      #
      # @param ports [Hash{String => Hash}] the ports hash for one service
      # @return [Hash{String => Hash}] new ports hash with extends references
      def compact_ports(ports)
        base_for_ops = {}
        result = {}

        ports.each do |port_name, port_data|
          operations = port_data['operations']
          base_name = find_base(base_for_ops, operations)

          if base_name
            result[port_name] = port_data.except('operations').merge('extends' => base_name).freeze
          else
            base_for_ops[port_name] = operations
            result[port_name] = freeze_port(port_data, operations)
          end
        end

        result
      end

      # Freezes a base port, ensuring the operations hash is frozen.
      #
      # @param port_data [Hash] the port hash
      # @param operations [Hash] the operations hash
      # @return [Hash] frozen port hash
      def freeze_port(port_data, operations)
        return port_data.freeze if operations.frozen?

        result = port_data.dup
        result['operations'] = operations.freeze
        result.freeze
      end

      # Finds the base port name for a given operations hash.
      #
      # Compares operations by value equality (+==+). Returns the name of
      # the first port that has identical operations, or +nil+ if no match.
      #
      # @param base_for_ops [Hash{String => Hash}] map of base port name to operations
      # @param operations [Hash] the operations hash to compare
      # @return [String, nil] base port name or nil
      def find_base(base_for_ops, operations)
        base_for_ops.each do |base_name, base_ops|
          return base_name if base_ops == operations
        end
        nil
      end
    end
  end
end
