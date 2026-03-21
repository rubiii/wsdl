# frozen_string_literal: true

module WSDL
  module TestService
    # A single input-criteria-to-response mapping.
    #
    # Created by {OperationDefinition#on} and used by the mock server
    # to find the correct response for a given SOAP request.
    #
    class ResponseMatcher
      # @return [Hash{Symbol => Object}] the input criteria to match against
      attr_reader :input_criteria

      # @return [Hash] the response hash to return when matched
      attr_reader :response

      # @param input_criteria [Hash{Symbol => Object}] leaf input values to match
      # @param response [Hash] the response body content
      def initialize(input_criteria:, response:)
        @input_criteria = input_criteria
        @response = response
      end

      # Checks if the extracted leaf values satisfy this matcher's criteria.
      #
      # @param leaf_values [Hash{Symbol => String}] extracted leaf values from the request
      # @return [Boolean]
      def match?(leaf_values)
        @input_criteria.all? do |key, expected|
          leaf_values[key].to_s == expected.to_s
        end
      end
    end
  end
end
