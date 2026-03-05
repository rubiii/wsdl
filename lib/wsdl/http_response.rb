# frozen_string_literal: true

module WSDL
  # Represents an HTTP response returned by an HTTP adapter.
  #
  # All HTTP adapter +get+ and +post+ methods must return an instance of
  # this class (or a compatible object responding to +status+, +headers+,
  # and +body+).
  #
  # @example Creating a response
  #   WSDL::HTTPResponse.new(status: 200, headers: {}, body: '<xml/>')
  #
  # @example From a custom adapter
  #   class MyAdapter
  #     def post(url, headers, body)
  #       resp = Faraday.post(url, body, headers)
  #       WSDL::HTTPResponse.new(status: resp.status, headers: resp.headers, body: resp.body)
  #     end
  #   end
  #
  HTTPResponse = Data.define(:status, :headers, :body) {
    # Creates a new HTTPResponse.
    #
    # @param status [Integer] HTTP status code
    # @param headers [Hash{String => String}] HTTP response headers
    # @param body [String] HTTP response body
    def initialize(status:, headers: {}, body: '')
      super
    end
  }
end
