# frozen_string_literal: true

module WSDL
  module Contract
    # Immutable request/response message contract.
    class MessageContract
      # @param header [PartContract]
      # @param body [PartContract]
      def initialize(header:, body:)
        @header = header
        @body = body
        freeze
      end

      # @return [PartContract]
      attr_reader :header

      # @return [PartContract]
      attr_reader :body

      # @return [Boolean]
      def empty?
        @header.paths.empty? && @body.paths.empty?
      end
    end
  end
end
