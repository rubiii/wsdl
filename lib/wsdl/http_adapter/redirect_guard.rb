# frozen_string_literal: true

require 'ipaddr'
require 'resolv'
require 'timeout'

module WSDL
  class HTTPAdapter
    # SSRF and redirect validation for {HTTPAdapter}.
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
      DNS_RESOLUTION_TIMEOUT = 5

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

      private

      # Validates that a redirect does not downgrade from HTTPS to HTTP.
      #
      # @param original_uri [URI] the original request URI
      # @param new_uri [URI] the redirect target URI
      # @raise [UnsafeRedirectError] if the scheme is downgraded
      def validate_redirect_scheme!(original_uri, new_uri)
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
      # @param uri [URI] the redirect target URI
      # @raise [UnsafeRedirectError] if any resolved address is private/reserved
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
      # @raise [UnsafeRedirectError] if resolution fails or any address is private
      def validate_resolved_addresses!(host, uri)
        resolved = Timeout.timeout(DNS_RESOLUTION_TIMEOUT) { Resolv.getaddresses(host) }
        resolved.each do |addr|
          resolved_ip = parse_ip(addr)
          raise_if_private!(resolved_ip, uri) if resolved_ip
        end
      rescue Resolv::ResolvError, SocketError, Timeout::Error
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
      # @param host [String] the string to parse
      # @return [IPAddr, nil] parsed IP address or nil
      def parse_ip(host)
        sanitized = host.split('%', 2).first
        IPAddr.new(sanitized)
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
