# frozen_string_literal: true

class WSDL
  # HTTP adapter using the httpclient gem.
  #
  # This is the default HTTP adapter used by {WSDL}. It wraps the
  # httpclient gem and provides a simple interface for making GET
  # and POST requests.
  #
  # @example Configuring the HTTP client
  #   wsdl = WSDL.new('http://example.com/service?wsdl')
  #   wsdl.http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
  #   wsdl.http.connect_timeout = 30
  #
  # @example Creating a custom adapter
  #   class MyHTTPAdapter
  #     def initialize
  #       @client = Faraday.new
  #     end
  #
  #     attr_reader :client
  #
  #     def get(url)
  #       @client.get(url).body
  #     end
  #
  #     def post(url, headers, body)
  #       @client.post(url, body, headers).body
  #     end
  #   end
  #
  #   WSDL.http_adapter = MyHTTPAdapter
  #
  class HTTPClient
    # Creates a new HTTPClient adapter instance.
    #
    # @raise [LoadError] if the httpclient gem is not installed
    def initialize
      require 'httpclient'
      @client = ::HTTPClient.new
    rescue LoadError
      raise LoadError,
            "The httpclient gem is required for the default HTTP adapter.\n" \
            "Either add `gem 'httpclient'` to your Gemfile, or configure a custom adapter:\n\n  " \
            "WSDL.http_adapter = MyCustomAdapter\n\n" \
            'See WSDL::HTTPClient documentation for the adapter interface.'
    end

    # Returns the underlying HTTPClient instance.
    #
    # Use this to configure connection settings like timeouts,
    # SSL options, proxy settings, etc.
    #
    # @return [::HTTPClient] the httpclient instance
    attr_reader :client

    # Executes an HTTP GET request.
    #
    # @param url [String] the URL to request
    # @return [String] the raw HTTP response body
    def get(url)
      request(:get, url, {}, nil)
    end

    # Executes an HTTP POST request.
    #
    # @param url [String] the URL to post to
    # @param headers [Hash] HTTP headers to include in the request
    # @param body [String] the request body
    # @return [String] the raw HTTP response body
    def post(url, headers, body)
      request(:post, url, headers, body)
    end

    private

    # Performs an HTTP request.
    #
    # @param method [Symbol] the HTTP method (:get, :post, etc.)
    # @param url [String] the URL to request
    # @param headers [Hash] HTTP headers
    # @param body [String, nil] the request body
    # @return [String] the response body
    def request(method, url, headers, body)
      response = @client.request(method, url, nil, body, headers)
      response.content
    end
  end
end
