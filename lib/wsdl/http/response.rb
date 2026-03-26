# frozen_string_literal: true

module WSDL
  module HTTP
    # Represents an HTTP response returned by an HTTP client.
    #
    # All HTTP client +get+ and +post+ methods must return an instance of
    # this class (or a compatible object responding to +status+, +headers+,
    # and +body+).
    #
    # @example Creating a response
    #   WSDL::HTTP::Response.new(status: 200, headers: {}, body: '<xml/>')
    #
    # @example From a custom client
    #   class MyHTTPClient
    #     def post(url, headers, body)
    #       resp = Faraday.post(url, body, headers)
    #       WSDL::HTTP::Response.new(status: resp.status, headers: resp.headers, body: resp.body)
    #     end
    #   end
    #
    Response = Data.define(:status, :headers, :body) {
      # Creates a new Response.
      #
      # @param status [Integer] HTTP status code
      # @param headers [Hash{String => String}] HTTP response headers
      # @param body [String] HTTP response body
      def initialize(status:, headers: {}, body: '')
        super
      end
    }
  end
end
