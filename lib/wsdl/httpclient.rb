# frozen_string_literal: true

require 'ipaddr'
require 'resolv'

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
  # - *Redirect SSRF protection:* Blocks redirects to private/reserved networks
  #
  # These defaults prevent indefinite hangs, redirect loops,
  # man-in-the-middle attacks, and SSRF via open redirects.
  # You can customize them via the underlying client if needed.
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
  #
  # Both IP address literals in the URL and DNS-resolved addresses
  # are checked. HTTPS-to-HTTP scheme downgrades are also blocked
  # (handled by the underlying httpclient gem).
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
  #       resp = @client.get(url)
  #       WSDL::HTTPResponse.new(status: resp.status, headers: resp.headers, body: resp.body)
  #     end
  #
  #     def post(url, headers, body)
  #       resp = @client.post(url, body, headers)
  #       WSDL::HTTPResponse.new(status: resp.status, headers: resp.headers, body: resp.body)
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

    # Private/reserved IPv4 and IPv6 ranges that must not be redirect targets.
    # @api private
    PRIVATE_IP_RANGES = [
      IPAddr.new('0.0.0.0/8'),       # Current network (RFC 1122)
      IPAddr.new('10.0.0.0/8'),      # Private (RFC 1918)
      IPAddr.new('100.64.0.0/10'),   # Shared address space (RFC 6598)
      IPAddr.new('127.0.0.0/8'),     # Loopback (RFC 1122)
      IPAddr.new('169.254.0.0/16'),  # Link-local (RFC 3927)
      IPAddr.new('172.16.0.0/12'),   # Private (RFC 1918)
      IPAddr.new('192.168.0.0/16'),  # Private (RFC 1918)
      IPAddr.new('::1/128'),         # IPv6 loopback
      IPAddr.new('fc00::/7'),        # IPv6 unique local (RFC 4193)
      IPAddr.new('fe80::/10')        # IPv6 link-local
    ].freeze

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
    # @return [HTTPResponse] the HTTP response
    def get(url)
      warn_if_ssl_verification_disabled
      request(:get, url, {}, nil)
    end

    # Executes an HTTP POST request.
    #
    # @param url [String] the URL to post to
    # @param headers [Hash] HTTP headers to include in the request
    # @param body [String] the request body
    # @return [HTTPResponse] the HTTP response
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
    # issues like indefinite hangs, redirect loops, and SSRF attacks.
    def apply_secure_defaults
      # Timeouts prevent indefinite hangs
      @client.connect_timeout = DEFAULT_CONNECT_TIMEOUT
      @client.send_timeout = DEFAULT_SEND_TIMEOUT
      @client.receive_timeout = DEFAULT_RECEIVE_TIMEOUT

      # Limit redirects to prevent loops and excessive chains
      @client.follow_redirect_count = DEFAULT_REDIRECT_LIMIT

      # Validate redirect targets to prevent SSRF via open redirects
      @client.redirect_uri_callback = method(:safe_redirect_uri_callback)

      # SSL verification is enabled by default in httpclient (VERIFY_PEER)
      # We don't change this, but we warn if the user disables it
    end

    # Redirect callback that validates targets before following.
    #
    # Resolves the +Location+ header from the redirect response, then
    # validates the resolved target is not a private or reserved IP address.
    # Also delegates HTTPS-to-HTTP downgrade protection to the httpclient
    # default callback.
    #
    # @param uri [URI] the original request URI
    # @param response [HTTP::Message] the redirect response
    # @return [URI] the validated redirect target URI
    # @raise [UnsafeRedirectError] if the redirect targets a private/reserved address
    #
    def safe_redirect_uri_callback(uri, response)
      new_uri = resolve_redirect_uri(uri, response)
      validate_redirect_target!(new_uri)

      # Delegate to default callback for HTTPS→HTTP downgrade protection
      @client.default_redirect_uri_callback(uri, response)
    end

    # Resolves the redirect target URI from a response's Location header.
    #
    # Handles both absolute and relative Location values by resolving
    # relative URIs against the original request URI.
    #
    # @param uri [URI] the original request URI
    # @param response [HTTP::Message] the redirect response
    # @return [URI] the resolved redirect target URI
    #
    def resolve_redirect_uri(uri, response)
      location = response.header['location']&.first
      return uri if location.nil?

      new_uri = URI.parse(location)
      new_uri = uri + new_uri unless new_uri.is_a?(URI::HTTP)
      new_uri
    end

    # Validates that a redirect target does not point to a private/reserved address.
    #
    # Checks the hostname as an IP literal first. If the hostname is a DNS name,
    # resolves it and checks all returned addresses. This prevents SSRF attacks
    # where a redirect targets internal network resources.
    #
    # @param uri [URI] the redirect target URI
    # @raise [UnsafeRedirectError] if any resolved address is private/reserved
    #
    def validate_redirect_target!(uri)
      host = uri.hostname || uri.host
      return if host.nil? || host.empty?

      # Check if host is an IP literal
      ip = parse_ip(host)
      if ip
        raise_if_private!(ip, uri)
        return
      end

      # Host is a DNS name — resolve and check all addresses
      resolved = Resolv.getaddresses(host)
      resolved.each do |addr|
        resolved_ip = parse_ip(addr)
        raise_if_private!(resolved_ip, uri) if resolved_ip
      end
    end

    # Parses a string as an IP address, returning nil if it's not a valid IP.
    #
    # @param host [String] the string to parse
    # @return [IPAddr, nil] parsed IP address or nil
    #
    def parse_ip(host)
      IPAddr.new(host)
    rescue IPAddr::InvalidAddressError
      nil
    end

    # Raises {UnsafeRedirectError} if the IP falls within a private/reserved range.
    #
    # @param ip [IPAddr] the IP address to check
    # @param uri [URI] the redirect target URI (for error context)
    # @raise [UnsafeRedirectError] if the IP is private/reserved
    #
    def raise_if_private!(ip, uri)
      return unless PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }

      raise UnsafeRedirectError.new(
        "Redirect to private/reserved address blocked: #{uri}. " \
        'This may indicate an SSRF attack via open redirect.',
        target_url: uri.to_s
      )
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
    # @return [HTTPResponse] the response
    def request(method, url, headers, body)
      response = @client.request(method, url, nil, body, headers)

      HTTPResponse.new(
        status: response.status,
        headers: response.headers,
        body: response.content
      )
    end
  end
end
