# frozen_string_literal: true

module WSDL
  module TestService
    # Extracts leaf (scalar) values from a nested hash into a flat key-value map.
    #
    # Used to flatten a parsed SOAP request body so that input criteria
    # can be matched regardless of nesting depth.
    #
    # @example
    #   InputExtractor.extract_leaves({ getBank: { blz: '70070010' } })
    #   # => { blz: '70070010' }
    #
    module InputExtractor
      module_function

      # Recursively extracts all leaf (non-Hash, non-Array) values from a nested hash.
      #
      # @param hash [Hash] the nested hash to extract from
      # @param result [Hash] accumulator (internal use)
      # @return [Hash{Symbol => String}] flat map of leaf keys to string values
      def extract_leaves(hash, result = {})
        hash.each do |key, value|
          case value
          when Hash
            extract_leaves(value, result)
          when Array
            value.each { |v| extract_leaves(v, result) if v.is_a?(Hash) }
          else
            result[key.to_sym] = value.to_s
          end
        end
        result
      end
    end
  end
end
