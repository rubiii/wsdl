# frozen_string_literal: true

module WSDL
  module Contract
    # Canonical contract/introspection surface for an operation.
    class OperationContract
      # @param operation_info [WSDL::Parser::OperationInfo]
      def initialize(operation_info)
        @operation_info = operation_info
        @request = MessageContract.new(
          header: PartContract.new(@operation_info.input.header_parts, section: :header),
          body: PartContract.new(@operation_info.input.body_parts, section: :body)
        )
        @response = MessageContract.new(
          header: PartContract.new(@operation_info.output.header_parts, section: :header),
          body: PartContract.new(@operation_info.output.body_parts, section: :body)
        )
        freeze
      end

      # @return [MessageContract]
      attr_reader :request

      # @return [MessageContract]
      attr_reader :response

      # @return [String] binding style (`document/literal` or `rpc/literal`)
      def style
        @operation_info.input_style
      end
    end
  end
end
