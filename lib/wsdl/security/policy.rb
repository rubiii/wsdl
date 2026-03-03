# frozen_string_literal: true

module WSDL
  module Security
    # Immutable container for request and response security policies.
    class Policy
      # @param request [RequestPolicy]
      # @param response [ResponsePolicy]
      def initialize(request:, response:)
        @request = request
        @response = response
        freeze
      end

      # Creates the default security policy.
      #
      # @return [Policy]
      #
      def self.default
        new(request: RequestPolicy.empty, response: ResponsePolicy.default)
      end

      # @return [RequestPolicy]
      attr_reader :request

      # @return [ResponsePolicy]
      attr_reader :response

      # @param request [RequestPolicy]
      # @return [Policy]
      def with_request(request)
        self.class.new(request:, response: @response)
      end

      # @param response [ResponsePolicy]
      # @return [Policy]
      def with_response(response)
        self.class.new(request: @request, response:)
      end
    end
  end
end
