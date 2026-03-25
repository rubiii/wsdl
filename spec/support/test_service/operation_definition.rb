# frozen_string_literal: true

module WSDL
  module TestService
    # Collects response matchers for a single WSDL operation.
    #
    # Built via the DSL inside a {ServiceDefinition#operation} block.
    # Each matcher maps input criteria to a response hash.
    #
    # @example
    #   operation :getBank do
    #     on blz: '70070010' do
    #       { details: { bezeichnung: 'Deutsche Bank' } }
    #     end
    #   end
    #
    class OperationDefinition
      # @param operation_name [Symbol] the WSDL operation name
      def initialize(operation_name)
        @operation_name = operation_name
        @matchers = []
      end

      # Defines a response for specific input values.
      #
      # The block must return a Hash representing the response body content
      # (without the wrapper element, which is added automatically from the schema).
      #
      # @param input_criteria [Hash{Symbol => Object}] leaf input values to match
      # @yield block that returns the response hash
      # @return [void]
      #
      # @example
      #   on blz: '70070010' do
      #     { details: { bezeichnung: 'Deutsche Bank' } }
      #   end
      def on(**input_criteria, &block)
        response_hash = block.call
        @matchers << ResponseMatcher.new(input_criteria:, response: response_hash)
      end

      # Finds the first matching response for the given parsed input hash.
      #
      # Extracts leaf values from the input hash and compares them against
      # each matcher's criteria.
      #
      # @param input_hash [Hash] parsed SOAP request body
      # @return [Hash, nil] the matching response hash, or nil
      def find_response(input_hash)
        leaves = InputExtractor.extract_leaves(input_hash)

        @matchers.find { |matcher| matcher.match?(leaves) }&.response
      end

      # Validates all input criteria and response hashes against their schemas.
      #
      # Uses the library's {WSDL::Response::Builder} for response validation
      # and checks input criteria against the request schema leaf elements.
      #
      # @param operation_name [Symbol] the operation name (for error messages)
      # @param input_elements [Array<WSDL::XML::Element>] request body schema elements
      # @param output_elements [Array<WSDL::XML::Element>] response body schema elements
      # @raise [ResponseDefinitionError] on any validation failure
      # @return [void]
      def validate!(operation_name, input_elements:, output_elements:)
        input_leaves = collect_leaf_elements(input_elements)
        builder = WSDL::Response::Builder.new(schema_elements: output_elements)

        @matchers.each do |matcher|
          validate_input_criteria(matcher.input_criteria, input_leaves, operation_name)
          builder.validate!(matcher.response)
        rescue WSDL::ResponseBuildError => e
          raise ResponseDefinitionError, "#{operation_name} (#{matcher.input_criteria.inspect}): #{e.message}"
        end
      end

      private

      def validate_input_criteria(criteria, input_leaves, operation_name)
        criteria.each do |key, value|
          element = input_leaves[key]

          unless element
            raise ResponseDefinitionError,
              "Unknown input element #{key.inspect} in on() for #{operation_name}. " \
              "Known input elements: #{input_leaves.keys.inspect}"
          end

          validate_input_type(value, element, key, operation_name)
        end
      end

      def validate_input_type(value, element, key, operation_name)
        allowed = allowed_classes_for(element.base_type)
        return if value.nil? || allowed.nil? || allowed.any? { |klass| value.is_a?(klass) }

        raise ResponseDefinitionError,
          "Type mismatch for input #{key.inspect} in on() for #{operation_name}: " \
          "expected #{element.base_type} (#{allowed.map(&:name).join('/')}) " \
          "but got #{value.class.name} (#{value.inspect})"
      end

      def allowed_classes_for(xsd_type)
        local_type = xsd_type&.split(':')&.last
        group = WSDL::Response::TypeCoercer::TYPE_GROUPS[local_type]
        WSDL::Response::Builder::TYPE_MAP[group]
      end

      def collect_leaf_elements(elements, result = {})
        elements.each do |element|
          if element.simple_type?
            result[element.name.to_sym] = element
          else
            collect_leaf_elements(element.children, result)
          end
        end
        result
      end
    end
  end
end
