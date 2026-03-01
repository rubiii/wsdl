# frozen_string_literal: true

require 'time'
require 'base64'
require 'openssl'

class WSDL
  module Security
    # Represents a WS-Security UsernameToken element.
    #
    # The UsernameToken provides username/password authentication for SOAP
    # messages. It supports both plain text and digest password modes.
    #
    # In digest mode, the password is computed as:
    #   Base64(SHA-1(nonce + created + password))
    #
    # This prevents the password from being transmitted in plain text and
    # provides replay attack protection through the nonce and timestamp.
    #
    # @example Plain text password
    #   token = UsernameToken.new('user', 'secret')
    #
    # @example Digest password
    #   token = UsernameToken.new('user', 'secret', digest: true)
    #
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
    #
    class UsernameToken
      include Constants

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
          PASSWORD_DIGEST_URI
        else
          PASSWORD_TEXT_URI
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
            xml['wsse'].Nonce(encoded_nonce, 'EncodingType' => BASE64_ENCODING_URI)
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
          token[:attributes!]['wsse:Nonce'] = { 'EncodingType' => BASE64_ENCODING_URI }
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

      private

      # Computes the password digest.
      #
      # The digest is computed as: Base64(SHA-1(nonce + created + password))
      # where nonce is the raw bytes, created is the XML timestamp string,
      # and password is the plain text password.
      #
      # @return [String] the Base64-encoded SHA-1 digest
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
