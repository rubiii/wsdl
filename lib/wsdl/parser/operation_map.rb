# frozen_string_literal: true

module WSDL
  module Parser
    # Stores operations by name, supporting WSDL 1.1 operation overloading.
    #
    # Both {PortType} and {Binding} use this to store their operations.
    # Consumers get clean single-operation lookups — overload handling
    # is encapsulated. Operations must respond to +#input_name+ for
    # disambiguation when overloaded.
    #
    # @example Non-overloaded lookup
    #   map.fetch('getBank')  # => PortTypeOperation
    #
    # @example Overloaded lookup with disambiguation
    #   map.fetch('Lookup', input_name: 'LookupById')  # => PortTypeOperation
    #
    # @api private
    class OperationMap
      def initialize
        @entries = {}
      end

      # Adds an operation. Multiple operations with the same name are allowed
      # per WSDL 1.1 §2.4.5 (operation overloading).
      #
      # @param name [String] the operation name
      # @param operation [Object] the operation (must respond to +#input_name+)
      # @return [void]
      def add(name, operation)
        (@entries[name] ||= []) << operation
      end

      # Returns unique operation names.
      #
      # @return [Array<String>]
      def keys
        @entries.keys
      end

      # Whether a name exists in the map.
      #
      # @param name [String]
      # @return [Boolean]
      def include?(name)
        @entries.key?(name)
      end

      # Fetches a single operation by name.
      #
      # For non-overloaded names, returns the operation directly. For
      # overloaded names, uses +input_name:+ to disambiguate. Raises
      # +ArgumentError+ if overloaded and no +input_name+ is provided.
      #
      # @param name [String] the operation name
      # @param input_name [String, Symbol, nil] disambiguator for overloaded operations
      # @yield fallback when name is not found (like +Hash#fetch+)
      # @return [Object] the matched operation
      # @raise [KeyError] if name is not found and no block given
      # @raise [ArgumentError] if overloaded and disambiguation fails
      def fetch(name, input_name: nil, &not_found)
        ops = @entries.fetch(name, &not_found)
        return ops unless ops.is_a?(Array)
        return ops.first if ops.one?

        resolve_overload(name, input_name, ops)
      end

      # Whether a specific name has multiple definitions.
      #
      # @param name [String]
      # @return [Boolean]
      def overloaded_name?(name)
        ops = @entries[name]
        !ops.nil? && ops.size > 1
      end

      # Number of definitions for a name.
      #
      # @param name [String]
      # @return [Integer]
      def overload_count(name)
        @entries[name]&.size || 0
      end

      private

      def resolve_overload(name, input_name, ops)
        unless input_name
          available = ops.filter_map(&:input_name)
          raise ArgumentError,
                "Operation #{name.inspect} is overloaded (#{ops.size} definitions). " \
                "Provide input_name: to disambiguate. Available: #{available.inspect}"
        end

        matched = ops.find { |op| op.input_name == input_name.to_s }
        return matched if matched

        raise ArgumentError,
              "No overload of #{name.inspect} with input_name: #{input_name.inspect}"
      end
    end
  end
end
