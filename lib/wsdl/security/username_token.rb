# frozen_string_literal: true

require 'time'
require 'base64'
require 'openssl'

module WSDL
  module Security
    # Represents a WS-Security UsernameToken element.
    #
    # The UsernameToken provides username/password authentication for SOAP
    # messages. It supports both plain text and digest password modes.
    #
    # == Security Comparison
    #
    # Choose the appropriate mode based on your security requirements:
    #
    # [Plain Text Mode] (+digest: false+, default)
    #   - Password is sent as-is in the SOAP message
    #   - *Must* only be used over HTTPS to protect the password in transit
    #   - Simpler but provides no replay protection
    #   - Suitable for: Development, trusted networks with HTTPS
    #
    # [Digest Mode] (+digest: true+, recommended)
    #   - Password is *never* transmitted
    #   - Computed as: +Base64(SHA-1(nonce + created + password))+
    #   - Provides replay attack protection via nonce and timestamp
    #   - Even if intercepted, attacker cannot recover the original password
    #   - Suitable for: Production environments, sensitive operations
    #
    # [X.509 Certificate Signatures] (strongest alternative)
    #   - For high-security requirements, consider using {Signature} instead
    #   - Supports SHA-256/SHA-512 (configurable)
    #   - Provides non-repudiation and stronger cryptographic guarantees
    #   - Suitable for: Compliance requirements, financial transactions
    #
    # == SHA-1 Protocol Limitation
    #
    # The WS-Security UsernameToken Profile 1.1 specification *mandates* SHA-1
    # for password digests. This is a protocol constraint, not a design choice.
    # Servers expecting WS-Security compliance will reject non-SHA-1 digests.
    #
    # While SHA-1 has known weaknesses (collision attacks), these do not
    # directly impact password digest security:
    #
    # - *Collision attacks* find two inputs with the same hash — not useful
    #   for password cracking
    # - *Preimage resistance* (recovering input from hash) remains
    #   computationally infeasible
    # - The *nonce changes every request*, preventing precomputation attacks
    # - The real risk is *weak passwords*, not SHA-1 itself
    #
    # For scenarios requiring stronger cryptographic algorithms, use
    # {Signature X.509 certificate signatures} which support SHA-256/SHA-512.
    #
    # == Recommendations
    #
    # 1. *Always use HTTPS* — regardless of password mode
    # 2. *Prefer digest mode* over plain text for production
    # 3. *Use strong passwords* — this is the primary security factor
    # 4. *Consider X.509 signatures* for high-security requirements
    #
    # @example Plain text password (use only over HTTPS)
    #   token = UsernameToken.new('user', 'secret')
    #
    # @example Digest password (recommended for production)
    #   token = UsernameToken.new('user', 'secret', digest: true)
    #
    # @note The digest algorithm (SHA-1) is mandated by the WS-Security
    #   UsernameToken Profile 1.1 specification and cannot be changed
    #   without breaking interoperability with compliant servers.
    #
    # @see Signature For X.509 certificate-based authentication (supports SHA-256/SHA-512)
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
    #   WS-Security UsernameToken Profile 1.1 Specification
    #
    class UsernameToken
      # Local aliases for token profile constants
      PasswordType = Constants::TokenProfiles::UsernameToken

      # Alias for encoding URI constants used in UsernameToken XML.
      #
      # @return [Module]
      Encoding = Constants::Encoding

      # Returns the username.
      # @return [String]
      attr_reader :username

      # Returns the password (plain text, before digest if applicable).
      # @return [String]
      attr_reader :password

      # Returns the creation timestamp.
      # @return [Time]
      attr_reader :created_at

      # Returns the unique ID for this token element.
      # @return [String]
      attr_reader :id

      # Creates a new UsernameToken instance.
      #
      # @param username [String] the username
      # @param password [String] the password
      # @param digest [Boolean] whether to use digest authentication (default: false)
      # @param created_at [Time, nil] the creation time (defaults to current UTC time)
      # @param id [String, nil] the wsu:Id attribute (auto-generated if nil)
      #
      def initialize(username, password, digest: false, created_at: nil, id: nil)
        @username = username
        @password = password
        @digest = digest
        @created_at = (created_at || Time.now).utc
        @id = id || IdGenerator.for('UsernameToken')
        @nonce = generate_nonce if digest?
      end

      # Returns whether digest authentication is enabled.
      #
      # @return [Boolean] true if using digest mode
      #
      def digest?
        @digest
      end

      # Returns the nonce value (only present in digest mode).
      #
      # @return [String, nil] the raw nonce bytes, or nil if not using digest
      #
      attr_reader :nonce

      # Returns the nonce encoded as Base64 (for XML output).
      #
      # @return [String, nil] the Base64-encoded nonce, or nil if not using digest
      #
      def encoded_nonce
        return nil unless @nonce

        Base64.strict_encode64(@nonce)
      end

      # Returns the created timestamp as an XML Schema dateTime string.
      #
      # @return [String] ISO 8601 formatted timestamp
      #
      def created_at_xml
        @created_at.xmlschema
      end

      # Returns the password value to include in the XML.
      #
      # For plain text mode, this is the original password.
      # For digest mode, this is Base64(SHA-1(nonce + created + password)).
      #
      # @return [String] the password or digest value
      #
      def password_value
        if digest?
          compute_digest
        else
          @password
        end
      end

      # Returns the password type URI for the XML Type attribute.
      #
      # @return [String] the password type URI
      #
      def password_type
        if digest?
          PasswordType::PASSWORD_DIGEST
        else
          PasswordType::PASSWORD_TEXT
        end
      end

      # Builds the XML representation of the UsernameToken element.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @return [void]
      #
      # @example Output XML structure (plain text)
      #   <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
      #     <wsse:Username>user</wsse:Username>
      #     <wsse:Password Type="...#PasswordText">secret</wsse:Password>
      #   </wsse:UsernameToken>
      #
      # @example Output XML structure (digest)
      #   <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
      #     <wsse:Username>user</wsse:Username>
      #     <wsse:Password Type="...#PasswordDigest">digest_value</wsse:Password>
      #     <wsse:Nonce EncodingType="...#Base64Binary">nonce_value</wsse:Nonce>
      #     <wsu:Created>2026-02-01T12:00:00Z</wsu:Created>
      #   </wsse:UsernameToken>
      #
      def to_xml(xml)
        xml['wsse'].UsernameToken('wsu:Id' => @id) do
          xml['wsse'].Username(@username)
          xml['wsse'].Password(password_value, 'Type' => password_type)

          if digest?
            xml['wsse'].Nonce(encoded_nonce, 'EncodingType' => Encoding::BASE64)
            xml['wsu'].Created(created_at_xml)
          end
        end
      end

      # Returns a Hash representation suitable for Gyoku XML generation.
      #
      # @return [Hash] the token structure as a hash
      #
      def to_hash
        token = {
          'wsse:Username' => @username,
          'wsse:Password' => password_value,
          :attributes! => {
            'wsse:Password' => { 'Type' => password_type }
          }
        }

        if digest?
          token['wsse:Nonce'] = encoded_nonce
          token['wsu:Created'] = created_at_xml
          token[:attributes!]['wsse:Nonce'] = { 'EncodingType' => Encoding::BASE64 }
          token[:order!] = ['wsse:Username', 'wsse:Password', 'wsse:Nonce', 'wsu:Created']
        else
          token[:order!] = ['wsse:Username', 'wsse:Password']
        end

        {
          'wsse:UsernameToken' => token,
          :attributes! => {
            'wsse:UsernameToken' => { 'wsu:Id' => @id }
          }
        }
      end

      # Returns a safe string representation that hides sensitive values.
      #
      # This method ensures that passwords and nonces are never accidentally
      # exposed in logs, error messages, debugger output, or stack traces.
      #
      # @return [String] a redacted representation safe for logging
      #
      # @example
      #   token = UsernameToken.new('admin', 'super_secret', digest: true)
      #   token.inspect
      #   # => '#<WSDL::Security::UsernameToken username="admin" password=[REDACTED] digest=true nonce=[REDACTED]>'
      #
      def inspect
        parts = [
          "username=#{@username.inspect}",
          'password=[REDACTED]',
          "digest=#{@digest}"
        ]
        parts << 'nonce=[REDACTED]' if @nonce

        "#<#{self.class.name} #{parts.join(' ')}>"
      end

      private

      # Computes the password digest per WS-Security UsernameToken Profile 1.1.
      #
      # The digest formula is mandated by the specification as:
      #   Base64(SHA-1(nonce + created + password))
      #
      # Where:
      # - +nonce+ is the raw bytes (16 cryptographically random bytes)
      # - +created+ is the XML Schema dateTime string (e.g., "2026-02-01T12:00:00Z")
      # - +password+ is the plain text password
      #
      # @note SHA-1 is required by the WS-Security specification. While SHA-1 has
      #   known collision weaknesses, preimage attacks (recovering the password
      #   from the digest) remain computationally infeasible. The nonce ensures
      #   each digest is unique, preventing replay and precomputation attacks.
      #
      # @return [String] the Base64-encoded SHA-1 digest
      #
      # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
      #   Section 4.1 - Sending Passwords in Digests
      #
      def compute_digest
        token = @nonce + created_at_xml + @password
        Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(token))
      end

      # Generates a cryptographically secure nonce.
      #
      # @return [String] 16 random bytes
      #
      def generate_nonce
        SecureRandom.random_bytes(16)
      end
    end
  end
end
