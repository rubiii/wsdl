# frozen_string_literal: true

module WSDL
  module Contract
    # Canonical contract/introspection surface for an operation.
    class OperationContract
      # @param input_header_parts [Array<Definition::ElementHash>] input header elements
      # @param input_body_parts [Array<Definition::ElementHash>] input body elements
      # @param output_header_parts [Array<Definition::ElementHash>] output header elements
      # @param output_body_parts [Array<Definition::ElementHash>] output body elements
      # @param input_style [String] binding style (e.g. 'document/literal')
      def initialize(input_header_parts:, input_body_parts:, output_header_parts:, output_body_parts:, input_style:)
        @request = MessageContract.new(
          header: PartContract.new(input_header_parts, section: :header),
          body: PartContract.new(input_body_parts, section: :body)
        )
        @response = MessageContract.new(
          header: PartContract.new(output_header_parts, section: :header),
          body: PartContract.new(output_body_parts, section: :body)
        )
        @input_style = input_style
        freeze
      end
      # @return [MessageContract]
      attr_reader :request

      # @return [MessageContract]
      attr_reader :response

      # @return [String] binding style (`document/literal` or `rpc/literal`)
      def style
        @input_style
      end
    end
  end
end
