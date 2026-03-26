# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'timeout'

module WSDL
  module HTTP
    # SSRF and redirect validation for {Client}.
    #
    # This module validates redirect targets to prevent Server-Side Request
    # Forgery (SSRF) attacks. It blocks redirects to private/reserved IP
    # addresses and prevents HTTPS-to-HTTP scheme downgrades.
    #
    # Both IP address literals in URLs and DNS-resolved addresses are checked.
    #
    # @api private
    module RedirectGuard
      # Timeout in seconds for DNS resolution during redirect validation.
      # Prevents indefinite hangs when resolving redirect target hostnames.
      #
      # Note: this timeout applies per redirect hop, so worst-case DNS latency
      # across a full redirect chain is +max_redirects × DNS_RESOLUTION_TIMEOUT+
      # (default: 5 × 5 = 25 seconds), on top of connection/read timeouts.
      DNS_RESOLUTION_TIMEOUT = 5

      # Private/reserved IPv4 and IPv6 ranges that must not be redirect targets.
      # @api private
      PRIVATE_IP_RANGES = [
        IPAddr.new('0.0.0.0/8'),          # Current network (RFC 1122)
        IPAddr.new('10.0.0.0/8'),         # Private (RFC 1918)
        IPAddr.new('100.64.0.0/10'),      # Shared address space (RFC 6598)
        IPAddr.new('127.0.0.0/8'),        # Loopback (RFC 1122)
        IPAddr.new('169.254.0.0/16'),     # Link-local (RFC 3927)
        IPAddr.new('172.16.0.0/12'),      # Private (RFC 1918)
        IPAddr.new('192.0.0.0/24'),       # IETF protocol assignments (RFC 6890)
        IPAddr.new('192.0.2.0/24'),       # Documentation TEST-NET-1 (RFC 5737)
        IPAddr.new('192.88.99.0/24'),     # 6to4 relay anycast (RFC 7526)
        IPAddr.new('192.168.0.0/16'),     # Private (RFC 1918)
        IPAddr.new('198.18.0.0/15'),      # Benchmarking (RFC 2544)
        IPAddr.new('198.51.100.0/24'),    # Documentation TEST-NET-2 (RFC 5737)
        IPAddr.new('203.0.113.0/24'),     # Documentation TEST-NET-3 (RFC 5737)
        IPAddr.new('240.0.0.0/4'),        # Reserved for future use (RFC 1112)
        IPAddr.new('255.255.255.255/32'), # Broadcast
        IPAddr.new('::/128'),             # IPv6 unspecified (RFC 4291)
        IPAddr.new('::1/128'),            # IPv6 loopback
        IPAddr.new('64:ff9b::/96'),       # NAT64 well-known prefix (RFC 6052)
        IPAddr.new('64:ff9b:1::/48'),     # NAT64 local-use prefix (RFC 8215)
        IPAddr.new('100::/64'),           # Discard-only prefix (RFC 6666)
        IPAddr.new('2001::/32'),          # Teredo tunneling (RFC 4380)
        IPAddr.new('2001:10::/28'),       # ORCHID addresses (RFC 4843)
        IPAddr.new('2001:db8::/32'),      # IPv6 documentation (RFC 3849)
        IPAddr.new('2002::/16'),          # 6to4 addresses (RFC 3056)
        IPAddr.new('fc00::/7'),           # IPv6 unique local (RFC 4193)
        IPAddr.new('fe80::/10')           # IPv6 link-local
      ].freeze

      # Headers that must be stripped when following a redirect to a different origin.
      # Prevents credential leakage on cross-origin 307/308 redirects where the
      # method, headers, and body are preserved.
      # @api private
      SENSITIVE_HEADERS = %w[
        authorization
        cookie
        proxy-authorization
      ].freeze

      private

      # Checks whether two URIs target different origins (different host or explicit port).
      #
      # Used to determine whether sensitive headers should be stripped on
      # method-preserving redirects (307/308). Only the host and explicitly
      # specified ports are compared — scheme-implied default port differences
      # (e.g., 80 vs 443 for an +http+ to +https+ upgrade) are ignored so that
      # legitimate TLS upgrades on the same host preserve credentials.
      #
      # @param original_uri [URI] the original request URI
      # @param new_uri [URI] the redirect target URI
      # @return [Boolean] true if the origins differ
      def cross_origin?(original_uri, new_uri)
        original_uri.host&.downcase != new_uri.host&.downcase ||
          explicit_port(original_uri) != explicit_port(new_uri)
      end

      # Returns the port only when it differs from the scheme default.
      #
      # @param uri [URI] the URI to inspect
      # @return [Integer, nil] the explicit port, or nil when it matches the scheme default
      def explicit_port(uri)
        port = uri.port
        port == uri.default_port ? nil : port
      end

      # Validates that a redirect uses an allowed scheme and does not downgrade from HTTPS to HTTP.
      #
      # Only +http+ and +https+ schemes are permitted. Redirects to other schemes
      # (e.g., +file+, +ftp+, +gopher+) are blocked to prevent local file access
      # and protocol smuggling attacks.
      #
      # @param original_uri [URI] the original request URI
      # @param new_uri [URI] the redirect target URI
      # @raise [UnsafeRedirectError] if the scheme is not HTTP/HTTPS or is downgraded
      def validate_redirect_scheme!(original_uri, new_uri)
        unless %w[http https].include?(new_uri.scheme)
          raise UnsafeRedirectError.new(
            "Redirect blocked: non-HTTP scheme '#{new_uri.scheme}' in #{new_uri}",
            target_url: new_uri.to_s
          )
        end

        return unless original_uri.scheme == 'https' && new_uri.scheme == 'http'

        raise UnsafeRedirectError.new(
          "Redirect blocked: HTTPS to HTTP downgrade from #{original_uri} to #{new_uri}. " \
          'This may expose sensitive data.',
          target_url: new_uri.to_s
        )
      end

      # Validates that a redirect target does not point to a private/reserved address.
      #
      # Checks the hostname as an IP literal first. If the hostname is a DNS name,
      # resolves it and checks all returned addresses. This prevents SSRF attacks
      # where a redirect targets internal network resources.
      #
      # Returns a validated IP address string that the caller should pin on the
      # +Net::HTTP+ connection via +ipaddr=+ to prevent DNS rebinding attacks.
      # Without pinning, +Net::HTTP+ performs its own DNS resolution, creating a
      # TOCTOU gap that an attacker can exploit by returning a safe address for
      # validation and a private address for the actual connection.
      #
      # @param uri [URI] the redirect target URI
      # @return [String, nil] a validated IP address to pin for the connection,
      #   or nil if the host is nil/empty
      # @raise [UnsafeRedirectError] if any resolved address is private/reserved
      def validate_redirect_target!(uri)
        host = uri.hostname || uri.host
        return if host.nil? || host.empty?

        # Check if host is an IP literal
        ip = parse_ip(host)
        if ip
          raise_if_private!(ip, uri)
          return ip.to_s
        end

        # Host is a DNS name — resolve and check all addresses
        validate_resolved_addresses!(host, uri)
      end

      # Resolves a hostname via DNS and validates all returned addresses.
      #
      # Uses a timeout to prevent hangs on slow/broken DNS resolvers.
      # If resolution fails for any reason, the redirect is blocked
      # since the target's safety cannot be verified.
      #
      # @param host [String] the hostname to resolve
      # @param uri [URI] the redirect target URI (for error context)
      # @return [String] the first resolved IP address to pin for the connection
      # @raise [UnsafeRedirectError] if resolution fails or any address is private
      def validate_resolved_addresses!(host, uri)
        resolved = resolve_addresses(host, uri)

        if resolved.empty?
          raise UnsafeRedirectError.new(
            "Redirect blocked: DNS resolution returned no addresses for #{host}. " \
            'Cannot verify redirect target is safe.',
            target_url: uri.to_s
          )
        end

        resolved.each do |addr|
          resolved_ip = parse_ip(addr)
          raise_if_private!(resolved_ip, uri) if resolved_ip
        end

        resolved.first
      end

      # Resolves a hostname via DNS with a timeout.
      #
      # @param host [String] the hostname to resolve
      # @param uri [URI] the redirect target URI (for error context)
      # @return [Array<String>] resolved IP address strings
      # @raise [UnsafeRedirectError] if DNS resolution fails for any reason
      def resolve_addresses(host, uri)
        Timeout.timeout(DNS_RESOLUTION_TIMEOUT) do
          Resolv.getaddresses(host)
        end
      rescue Resolv::ResolvError, SocketError, Timeout::Error, SystemCallError, IOError
        raise UnsafeRedirectError.new(
          "Redirect blocked: DNS resolution failed for #{uri.host}. " \
          'Cannot verify redirect target is safe.',
          target_url: uri.to_s
        )
      end

      # Parses a string as an IP address, returning nil if it's not a valid IP.
      #
      # Strips IPv6 zone IDs (e.g., `%eth0` in `fe80::1%eth0`) before parsing.
      # Zone IDs are interface-scoped and not relevant for SSRF range checks,
      # but would cause {IPAddr} to reject the address, bypassing validation.
      #
      # IPv4-mapped IPv6 addresses (e.g., `::ffff:127.0.0.1`) and deprecated
      # IPv4-compatible IPv6 addresses (e.g., `::127.0.0.1`) are normalized
      # to their native IPv4 form via {IPAddr#native} so they are matched
      # against IPv4 private ranges. Without this, an attacker could bypass
      # all IPv4 range checks by using either representation.
      #
      # @param host [String] the string to parse
      # @return [IPAddr, nil] parsed IP address or nil
      def parse_ip(host)
        sanitized = host.split('%', 2).first
        IPAddr.new(sanitized).native
      rescue IPAddr::InvalidAddressError
        nil
      end

      # Raises {UnsafeRedirectError} if the IP falls within a private/reserved range.
      #
      # @param ip [IPAddr] the IP address to check
      # @param uri [URI] the redirect target URI (for error context)
      # @raise [UnsafeRedirectError] if the IP is private/reserved
      def raise_if_private!(ip, uri)
        return unless PRIVATE_IP_RANGES.any? { |range| range.include?(ip) }

        raise UnsafeRedirectError.new(
          "Redirect to private/reserved address blocked: #{uri}. " \
          'This may indicate an SSRF attack via open redirect.',
          target_url: uri.to_s
        )
      end
    end
  end
end
