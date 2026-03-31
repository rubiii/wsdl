# frozen_string_literal: true

module WSDL
  class Definition
    # Extracts operation fields that are uniform across all operations in a
    # port into a port-level +"defaults"+ hash. Operations in the output
    # omit those fields — they are merged back at read time by Definition.
    #
    # Runs after {TypeCompactor} in the Builder pipeline. Unlike the other
    # compactors, this one does not produce a separate data structure —
    # it returns the modified services hash directly.
    #
    # @example
    #   services = DefaultsCompactor.call(services)
    #
    # @api private
    #
    class DefaultsCompactor
      # Operation fields that are never extracted into port-level defaults.
      #
      # These fields are per-operation by nature (name, message structures,
      # SOAP action) and must always remain on each operation hash.
      #
      # @return [Array<String>]
      EXCLUDED_FIELDS = %w[name input_name soap_action input output].freeze

      # Compacts uniform operation fields into port-level defaults.
      #
      # @param services [Hash] the services hash (post-type-compaction)
      # @return [Hash] compacted services hash with defaults extracted
      def self.call(services)
        new(services).call
      end

      # @param services [Hash] the services hash (post-type-compaction)
      def initialize(services)
        @services = services
      end

      # Walks all ports and extracts uniform operation fields into defaults.
      #
      # @return [Hash] compacted services hash
      def call
        compact_services
      end

      private

      # Compacts all services by extracting port-level operation defaults.
      #
      # @return [Hash] new services hash with defaults extracted
      def compact_services
        @services.transform_values { |svc_data|
          {
            'ports' => svc_data['ports'].transform_values { |port|
              compact_port(port)
            }.freeze
          }.freeze
        }.freeze
      end

      # Compacts a single port by extracting uniform operation fields into defaults.
      #
      # Collects all operation hashes (flattening overloaded Array entries),
      # finds fields that are uniform across all operations (excluding
      # per-operation fields like +name+, +soap_action+, +input+, +output+),
      # and extracts them into a +"defaults"+ hash on the port.
      #
      # @param port [Hash] port hash from services
      # @return [Hash] new port hash with defaults extracted
      def compact_port(port)
        ops = collect_all_ops(port['operations'])
        return port.freeze unless ops.any?

        defaults = extract_uniform_fields(ops)
        return port.freeze if defaults.empty?

        result = port.dup
        result['defaults'] = defaults.freeze
        result['operations'] = strip_defaults_from_operations(port['operations'], defaults.keys)
        result.freeze
      end

      # Collects all operation hashes from a port's operations, flattening overloads.
      #
      # @param operations [Hash{String => Hash, Array<Hash>}] the operations hash
      # @return [Array<Hash>] all individual operation hashes
      def collect_all_ops(operations)
        operations.each_value.flat_map { |entry| entry.is_a?(Array) ? entry : [entry] }
      end

      # Finds fields that are uniform across all operations.
      #
      # A field is uniform when every operation has the same value for it
      # (including +nil+). Fields listed in {EXCLUDED_FIELDS} are never
      # considered candidates.
      #
      # @param ops [Array<Hash>] all operation hashes (flattened)
      # @return [Hash{String => Object}] uniform field/value pairs
      def extract_uniform_fields(ops)
        first = ops.first
        candidate_keys = first.keys - EXCLUDED_FIELDS

        candidate_keys.each_with_object({}) do |key, defaults|
          value = first[key]
          defaults[key] = value if ops.all? { |op| op[key] == value }
        end
      end

      # Produces a new operations hash with default keys stripped from each operation.
      #
      # Handles both single operations and overloaded Array entries.
      #
      # @param operations [Hash{String => Hash, Array<Hash>}] the original operations hash
      # @param default_keys [Array<String>] keys to remove from each operation
      # @return [Hash{String => Hash, Array<Hash>}] new operations hash
      def strip_defaults_from_operations(operations, default_keys)
        operations.transform_values { |entry|
          if entry.is_a?(Array)
            entry.map { |op| op.except(*default_keys).freeze }.freeze
          else
            entry.except(*default_keys).freeze
          end
        }.freeze
      end
    end
  end
end
