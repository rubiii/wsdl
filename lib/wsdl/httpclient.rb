# frozen_string_literal: true

module WSDL
  # HTTP adapter using the httpclient gem.
  #
  # This is the default HTTP adapter used by {WSDL}. It wraps the
  # httpclient gem and provides a simple interface for making GET
  # and POST requests.
  #
  # == Security Defaults
  #
  # This adapter applies secure defaults out of the box:
  #
  # - *Connection timeout:* 30 seconds
  # - *Send timeout:* 60 seconds
  # - *Receive timeout:* 120 seconds
  # - *Redirect limit:* 5 redirects maximum
  # - *SSL verification:* Enabled by default (VERIFY_PEER)
  #
  # These defaults prevent indefinite hangs, redirect loops, and
  # man-in-the-middle attacks. You can customize them via the
  # underlying client if needed.
  #
  # @example Configuring timeouts
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.connect_timeout = 30
  #   client.http.receive_timeout = 60
  #
  # @example Using a custom CA certificate
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.ssl_config.add_trust_ca('/path/to/ca-bundle.crt')
  #
  # @example Client certificate authentication (mutual TLS)
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.ssl_config.set_client_cert_file(
  #     '/path/to/client.crt',
  #     '/path/to/client.key'
  #   )
  #
  # @see file:docs/configuration.md Configuration Guide
  #
  # @example Creating a custom adapter
  #   class MyHTTPAdapter
  #     def initialize
  #       @client = Faraday.new
  #     end
  #
  #     attr_reader :client
  #
  #     def cache_key
  #       'my-http-adapter:v1'
  #     end
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
    include Log

    # Default connection timeout in seconds.
    # This is the maximum time to wait for a connection to be established.
    DEFAULT_CONNECT_TIMEOUT = 30

    # Default send timeout in seconds.
    # This is the maximum time to wait for sending request data.
    DEFAULT_SEND_TIMEOUT = 60

    # Default receive timeout in seconds.
    # This is the maximum time to wait for receiving response data.
    DEFAULT_RECEIVE_TIMEOUT = 120

    # Default maximum number of redirects to follow.
    # Prevents redirect loops and excessive redirect chains.
    DEFAULT_REDIRECT_LIMIT = 5

    # Creates a new HTTPClient adapter instance.
    #
    # Applies secure defaults for timeouts and redirect handling.
    # SSL certificate verification is enabled by default.
    #
    # @raise [LoadError] if the httpclient gem is not installed
    def initialize
      require 'httpclient'
      @client = ::HTTPClient.new

      apply_secure_defaults
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

    # Returns a stable cache fingerprint for parser cache partitioning.
    #
    # @return [String] adapter cache identity
    def cache_key
      self.class.name
    end

    # Executes an HTTP GET request.
    #
    # @param url [String] the URL to request
    # @return [String] the raw HTTP response body
    def get(url)
      warn_if_ssl_verification_disabled
      request(:get, url, {}, nil)
    end

    # Executes an HTTP POST request.
    #
    # @param url [String] the URL to post to
    # @param headers [Hash] HTTP headers to include in the request
    # @param body [String] the request body
    # @return [String] the raw HTTP response body
    def post(url, headers, body)
      warn_if_ssl_verification_disabled
      request(:post, url, headers, body)
    end

    # Checks if SSL certificate verification is currently disabled.
    #
    # @return [Boolean] true if SSL verification is disabled
    def ssl_verification_disabled?
      require 'openssl'
      @client.ssl_config.verify_mode == OpenSSL::SSL::VERIFY_NONE
    end

    private

    # Applies secure default settings to the HTTP client.
    #
    # These defaults provide reasonable security and prevent common
    # issues like indefinite hangs and redirect loops.
    def apply_secure_defaults
      # Timeouts prevent indefinite hangs
      @client.connect_timeout = DEFAULT_CONNECT_TIMEOUT
      @client.send_timeout = DEFAULT_SEND_TIMEOUT
      @client.receive_timeout = DEFAULT_RECEIVE_TIMEOUT

      # Limit redirects to prevent loops and excessive chains
      @client.follow_redirect_count = DEFAULT_REDIRECT_LIMIT

      # SSL verification is enabled by default in httpclient (VERIFY_PEER)
      # We don't change this, but we warn if the user disables it
    end

    # Logs a warning if SSL verification has been disabled.
    #
    # This warning is logged once per adapter instance to avoid
    # flooding logs during normal operation.
    def warn_if_ssl_verification_disabled
      return if @ssl_warning_logged
      return unless ssl_verification_disabled?

      @ssl_warning_logged = true
      logger.warn(
        'SSL certificate verification is disabled. ' \
        'This makes connections vulnerable to man-in-the-middle attacks. ' \
        'Only disable verification in development/testing environments.'
      )
    end

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
