# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'uri'

require 'wsdl/http_adapter/config'
require 'wsdl/http_adapter/redirect_guard'

module WSDL
  # HTTP adapter using Ruby's stdlib +net/http+.
  #
  # This is the default HTTP adapter used by {WSDL}. It provides a simple
  # interface for making GET and POST requests with no external dependencies.
  #
  # == Security Defaults
  #
  # This adapter applies secure defaults out of the box:
  #
  # - *Open timeout:* 30 seconds
  # - *Write timeout:* 60 seconds
  # - *Read timeout:* 120 seconds
  # - *Redirect limit:* 5 redirects maximum
  # - *SSL verification:* Enabled by default (VERIFY_PEER)
  # - *Redirect SSRF protection:* Blocks redirects to private/reserved networks
  # - *Scheme downgrade protection:* Blocks HTTPS-to-HTTP redirects
  #
  # These defaults prevent indefinite hangs, redirect loops,
  # man-in-the-middle attacks, and SSRF via open redirects.
  # You can customize them via {#config} which returns a {Config} instance.
  #
  # == Redirect Security
  #
  # HTTP redirects are validated before following. The adapter blocks
  # redirects that target private or reserved IP addresses to prevent
  # SSRF (Server-Side Request Forgery) attacks. This protects against
  # scenarios where a malicious WSDL endpoint redirects to internal
  # network addresses such as cloud metadata services (+169.254.169.254+),
  # loopback interfaces (+127.0.0.1+), or RFC 1918 private networks.
  #
  # Blocked address ranges:
  # - Loopback: +127.0.0.0/8+, +::1+
  # - Private: +10.0.0.0/8+, +172.16.0.0/12+, +192.168.0.0/16+
  # - Link-local: +169.254.0.0/16+, +fe80::/10+
  # - Current network: +0.0.0.0/8+
  # - Shared address space: +100.64.0.0/10+
  # - IETF protocol assignments: +192.0.0.0/24+
  # - Documentation: +192.0.2.0/24+, +198.51.100.0/24+, +203.0.113.0/24+
  # - 6to4 relay anycast: +192.88.99.0/24+
  # - Benchmarking: +198.18.0.0/15+
  # - Reserved/broadcast: +240.0.0.0/4+, +255.255.255.255+
  # - IPv6 unspecified: +::/128+
  # - NAT64: +64:ff9b::/96+, +64:ff9b:1::/48+
  # - Discard-only: +100::/64+
  # - Teredo: +2001::/32+
  # - ORCHID: +2001:10::/28+
  # - IPv6 documentation: +2001:db8::/32+
  # - 6to4: +2002::/16+
  #
  # Both IP address literals in the URL and DNS-resolved addresses
  # are checked. HTTPS-to-HTTP scheme downgrades are also blocked.
  #
  # @example Configuring timeouts
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.open_timeout = 10
  #   client.http.read_timeout = 60
  #
  # @example Using a custom CA certificate
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.ca_file = '/path/to/ca-bundle.crt'
  #
  # @example Client certificate authentication (mutual TLS)
  #   client = WSDL::Client.new('https://example.com/service?wsdl')
  #   client.http.cert = OpenSSL::X509::Certificate.new(File.read('/path/to/client.crt'))
  #   client.http.key = OpenSSL::PKey::RSA.new(File.read('/path/to/client.key'))
  #
  # @see file:docs/core/configuration.md Configuration Guide
  #
  # @example Creating a custom adapter
  #   class MyHTTPAdapter
  #     def initialize
  #       @connection = Faraday.new
  #     end
  #
  #     # Expose the Faraday connection for user configuration
  #     # (e.g. client.http.options.timeout = 30).
  #     attr_reader :connection
  #     alias config connection
  #
  #     def get(url)
  #       resp = @connection.get(url)
  #       WSDL::HTTPResponse.new(status: resp.status, headers: resp.headers, body: resp.body)
  #     end
  #
  #     def post(url, headers, body)
  #       resp = @connection.post(url, body, headers)
  #       WSDL::HTTPResponse.new(status: resp.status, headers: resp.headers, body: resp.body)
  #     end
  #   end
  #
  #   WSDL.http_adapter = MyHTTPAdapter
  #
  class HTTPAdapter
    include Log
    include RedirectGuard

    # HTTP redirect status codes.
    # @api private
    REDIRECT_CODES = [301, 302, 303, 307, 308].freeze

    # Redirect codes that change the method to GET (RFC 7231).
    # @api private
    REDIRECT_TO_GET_CODES = [301, 302, 303].freeze

    # Creates a new HTTPAdapter instance with secure defaults.
    def initialize
      @config = Config.new
    end

    # Returns the {Config} instance for customizing timeouts, SSL, and redirects.
    #
    # @return [Config] the configuration object
    attr_reader :config

    # Executes an HTTP GET request.
    #
    # @param url [String] the URL to request
    # @return [HTTPResponse] the HTTP response
    def get(url)
      warn_if_ssl_verification_disabled
      request_with_redirects(:get, URI(url))
    end

    # Executes an HTTP POST request.
    #
    # @param url [String] the URL to post to
    # @param headers [Hash] HTTP headers to include in the request
    # @param body [String] the request body
    # @return [HTTPResponse] the HTTP response
    def post(url, headers, body)
      warn_if_ssl_verification_disabled
      request_with_redirects(:post, URI(url), headers, body)
    end

    # Checks if SSL certificate verification is currently disabled.
    #
    # @return [Boolean] true if SSL verification is disabled
    def ssl_verification_disabled?
      @config.verify_mode == OpenSSL::SSL::VERIFY_NONE
    end

    private

    # Follows redirects up to {Config#max_redirects} times, validating each target.
    #
    # @param method [Symbol] the HTTP method (:get or :post)
    # @param uri [URI] the request URI
    # @param headers [Hash] HTTP headers
    # @param body [String, nil] the request body
    # @return [HTTPResponse] the final response
    # @raise [TooManyRedirectsError] if the redirect limit is exceeded
    # @raise [UnsafeRedirectError] if a redirect targets a private/reserved address or downgrades HTTPS to HTTP
    def request_with_redirects(method, uri, headers = {}, body = nil)
      redirects = 0

      resolved_ip = nil

      loop do
        response = perform_request(method, uri, headers, body, resolved_ip:)

        return response unless REDIRECT_CODES.include?(response.status)

        redirects += 1
        check_redirect_limit!(redirects)

        new_uri = resolve_redirect_uri(uri, response)
        validate_redirect_scheme!(uri, new_uri)
        resolved_ip = validate_redirect_target!(new_uri)

        if REDIRECT_TO_GET_CODES.include?(response.status)
          method = :get
          headers = {}
          body = nil
        elsif cross_origin?(uri, new_uri)
          headers = strip_sensitive_headers(headers)
        end

        uri = new_uri
      end
    end

    # Raises if the redirect count exceeds the configured limit.
    #
    # @param count [Integer] current redirect count
    # @raise [TooManyRedirectsError] if the limit is exceeded
    def check_redirect_limit!(count)
      return unless count > @config.max_redirects

      raise TooManyRedirectsError,
        "Too many redirects (limit: #{@config.max_redirects})"
    end

    # Returns a copy of the headers hash with sensitive headers removed.
    #
    # Used when following cross-origin 307/308 redirects to prevent
    # leaking credentials to a different origin.
    #
    # @param headers [Hash] the original request headers
    # @return [Hash] headers with sensitive entries removed
    def strip_sensitive_headers(headers)
      headers.reject { |key, _| RedirectGuard::SENSITIVE_HEADERS.include?(key.downcase) }
    end

    # Resolves the redirect target URI from a response's Location header.
    #
    # Raises if the Location header is missing, empty, or malformed.
    # A redirect without a valid Location is a protocol violation
    # (RFC 7231 §7.1.2) and must not silently consume redirect budget.
    #
    # @param uri [URI] the original request URI
    # @param response [HTTPResponse] the redirect response
    # @return [URI] the resolved redirect target URI
    # @raise [UnsafeRedirectError] if the Location header is missing, empty, or unparseable
    def resolve_redirect_uri(uri, response)
      location = response.headers['location']

      if location.nil? || location.strip.empty?
        raise UnsafeRedirectError.new(
          "Redirect blocked: response has no Location header (status #{response.status})",
          target_url: uri.to_s
        )
      end

      new_uri = URI(location)
      new_uri = uri + location unless new_uri.is_a?(URI::HTTP)
      new_uri
    rescue URI::InvalidURIError, URI::BadURIError
      raise UnsafeRedirectError.new(
        "Redirect blocked: malformed Location header '#{location[0, 200]}'",
        target_url: location
      )
    end

    # Performs a single HTTP request using +Net::HTTP+.
    #
    # When +resolved_ip+ is provided, the connection is pinned to that address
    # via +Net::HTTP#ipaddr=+, bypassing +Net::HTTP+'s own DNS resolution.
    # This prevents DNS rebinding attacks where an attacker returns a safe
    # address during validation but a private address during connection.
    #
    # @param method [Symbol] the HTTP method
    # @param uri [URI] the request URI
    # @param headers [Hash] HTTP headers
    # @param body [String, nil] the request body
    # @param resolved_ip [String, nil] a validated IP address to pin for the connection
    # @return [HTTPResponse] the response
    def perform_request(method, uri, headers, body, resolved_ip: nil)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.ipaddr = resolved_ip if resolved_ip
      http.use_ssl = (uri.scheme == 'https')
      apply_config(http)

      http.start do
        request = build_request(method, uri, headers, body)
        response = http.request(request)

        HTTPResponse.new(
          status: response.code.to_i,
          headers: extract_headers(response),
          body: response.body
        )
      end
    end

    # Applies {Config} settings to a +Net::HTTP+ instance.
    #
    # @param http [Net::HTTP] the connection to configure
    def apply_config(http)
      apply_timeouts(http)
      apply_ssl_config(http)
    end

    # Applies timeout settings to a +Net::HTTP+ instance.
    #
    # @param http [Net::HTTP] the connection to configure
    def apply_timeouts(http)
      http.open_timeout = @config.open_timeout
      http.write_timeout = @config.write_timeout
      http.read_timeout = @config.read_timeout
    end

    # Applies SSL settings to a +Net::HTTP+ instance.
    #
    # @param http [Net::HTTP] the connection to configure
    def apply_ssl_config(http) # rubocop:disable Metrics/AbcSize
      http.verify_mode = @config.verify_mode
      http.ca_file = @config.ca_file if @config.ca_file
      http.ca_path = @config.ca_path if @config.ca_path
      http.cert = @config.cert if @config.cert
      http.key = @config.key if @config.key
      http.min_version = @config.min_version if @config.min_version
      http.max_version = @config.max_version if @config.max_version
    end

    # Builds a +Net::HTTP+ request object.
    #
    # @param method [Symbol] the HTTP method
    # @param uri [URI] the request URI
    # @param headers [Hash] HTTP headers
    # @param body [String, nil] the request body
    # @return [Net::HTTPRequest] the request
    def build_request(method, uri, headers, body)
      klass = method == :post ? Net::HTTP::Post : Net::HTTP::Get
      request = klass.new(uri)

      # Disable transparent gzip decompression to prevent gzip bombs.
      # A small compressed payload could decompress into gigabytes in memory
      # before document size limits can be checked.
      request['Accept-Encoding'] = 'identity'

      headers.each do |k, v|
        request[k] = v
      end
      request.body = body if body

      request
    end

    # Extracts response headers into a plain Hash.
    #
    # @param response [Net::HTTPResponse] the response
    # @return [Hash{String => String}] the headers
    def extract_headers(response)
      headers = {}
      response.each_header do |k, v|
        headers[k] = v
      end
      headers
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
  end
end
