# frozen_string_literal: true

require 'openssl'

module WSDL
  module Security
    # Configuration container for WS-Security settings on an operation.
    #
    # The Config class provides a fluent interface for configuring various
    # WS-Security features including UsernameToken authentication, timestamps,
    # and X.509 certificate signing.
    #
    # @example UsernameToken authentication
    #   config = Config.new
    #   config.username_token('user', 'secret')
    #
    # @example Digest authentication
    #   config.username_token('user', 'secret', digest: true)
    #
    # @example X.509 signing
    #   config.signature(
    #     certificate: cert,
    #     private_key: key,
    #     digest_algorithm: :sha256
    #   )
    #
    # @example Combined configuration
    #   config.timestamp(expires_in: 300)
    #   config.username_token('user', 'secret')
    #   config.signature(certificate: cert, private_key: key)
    #
    # @example Sign WS-Addressing headers
    #   config.signature(certificate: cert, private_key: key, sign_addressing: true)
    #
    # @example Use explicit namespace prefixes
    #   config.signature(certificate: cert, private_key: key, explicit_namespace_prefixes: true)
    #
    # @example Use IssuerSerial key reference
    #   config.signature(certificate: cert, private_key: key, key_reference: :issuer_serial)
    #
    # rubocop:disable Metrics/ClassLength -- Config has many security features requiring extensive documentation
    class Config
      # Local alias for key reference constants
      KeyRef = Constants::KeyReference

      # Returns the UsernameToken configuration.
      # @return [UsernameToken, nil]
      attr_reader :username_token_config

      # Returns the Timestamp configuration.
      # @return [Timestamp, nil]
      attr_reader :timestamp_config

      # Returns the Signature configuration.
      # @return [Signature, nil]
      attr_reader :signature_config

      # Returns the trust store to use for certificate chain validation.
      # @return [OpenSSL::X509::Store, Symbol, String, Array, nil]
      attr_reader :verification_trust_store

      # Returns whether certificate validity period checking is enabled.
      # @return [Boolean]
      attr_reader :check_certificate_validity

      # Returns whether timestamp validation is enabled for response verification.
      # @return [Boolean]
      attr_reader :validate_timestamp

      # Returns the clock skew tolerance in seconds for timestamp validation.
      # @return [Integer]
      attr_reader :clock_skew

      # Creates a new Config instance.
      #
      def initialize
        @username_token_config = nil
        @timestamp_config = nil
        @signature_config = nil
        @signature_options = nil
        @verify_response = false
        @verification_trust_store = nil
        @check_certificate_validity = true
        @validate_timestamp = true
        @clock_skew = 300
      end

      # Configures UsernameToken authentication.
      #
      # @param username [String] the username
      # @param password [String] the password
      # @param digest [Boolean] whether to use digest authentication (default: false)
      # @param created_at [Time, nil] the creation timestamp (defaults to current time)
      #
      # @return [self] for method chaining
      #
      # @example Plain text password
      #   config.username_token('user', 'secret')
      #
      # @example Digest password
      #   config.username_token('user', 'secret', digest: true)
      #
      def username_token(username, password, digest: false, created_at: nil)
        @username_token_config = UsernameToken.new(
          username, password,
          digest: digest,
          created_at: created_at
        )
        self
      end

      # Configures a wsu:Timestamp header.
      #
      # @param created_at [Time, nil] the creation time (defaults to current time)
      # @param expires_in [Integer] seconds until expiration (default: 300)
      # @param expires_at [Time, nil] explicit expiration time
      #
      # @return [self] for method chaining
      #
      # @example Default 5-minute expiration
      #   config.timestamp
      #
      # @example Custom expiration
      #   config.timestamp(expires_in: 600) # 10 minutes
      #
      def timestamp(created_at: nil, expires_in: Timestamp::DEFAULT_TTL, expires_at: nil)
        @timestamp_config = Timestamp.new(
          created_at: created_at,
          expires_in: expires_in,
          expires_at: expires_at
        )
        self
      end

      # Configures X.509 certificate signing.
      #
      # @param certificate [OpenSSL::X509::Certificate, String] the certificate
      #   (PEM string or Certificate object)
      # @param private_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC, String] the private key
      #   (PEM string or key object)
      # @param options [Hash] additional signing options
      # @option options [String, nil] :key_password password for encrypted private key
      # @option options [Symbol] :digest_algorithm the digest algorithm (:sha1, :sha256, :sha512)
      # @option options [Boolean] :sign_body whether to sign the SOAP body (default: true)
      # @option options [Boolean] :sign_timestamp whether to sign the timestamp (default: true)
      # @option options [Boolean] :sign_addressing whether to sign WS-Addressing headers (default: false)
      # @option options [Boolean] :explicit_namespace_prefixes whether to use explicit namespace
      #   prefixes like ds:Signature instead of default namespace (default: false)
      # @option options [Symbol] :key_reference how to reference the signing certificate in KeyInfo:
      #   - :binary_security_token (default) - embed certificate in BinarySecurityToken
      #   - :issuer_serial - reference by issuer DN and serial number
      #   - :subject_key_identifier - reference by Subject Key Identifier extension
      #
      # @return [self] for method chaining
      #
      # @example Basic signing
      #   config.signature(certificate: cert, private_key: key)
      #
      # @example With SHA-256
      #   config.signature(
      #     certificate: cert,
      #     private_key: key,
      #     digest_algorithm: :sha256
      #   )
      #
      # @example From PEM strings
      #   config.signature(
      #     certificate: File.read('cert.pem'),
      #     private_key: File.read('key.pem'),
      #     key_password: 'secret'
      #   )
      #
      # @example Sign WS-Addressing headers (for routing attack prevention)
      #   config.signature(
      #     certificate: cert,
      #     private_key: key,
      #     sign_addressing: true
      #   )
      #
      # @example Use explicit namespace prefixes (for strict servers)
      #   config.signature(
      #     certificate: cert,
      #     private_key: key,
      #     explicit_namespace_prefixes: true
      #   )
      #
      # @example Use IssuerSerial key reference (smaller messages)
      #   config.signature(
      #     certificate: cert,
      #     private_key: key,
      #     key_reference: :issuer_serial
      #   )
      #
      def signature(certificate:, private_key:, **options)
        cert = normalize_certificate(certificate)
        key = normalize_private_key(private_key, options[:key_password])

        @signature_options = SignatureOptions.from_hash(options)
        validate_key_reference!(@signature_options.key_reference, cert)

        @signature_config = Signature.new(
          certificate: cert,
          private_key: key,
          digest_algorithm: @signature_options.digest_algorithm,
          key_reference: @signature_options.key_reference,
          explicit_namespace_prefixes: @signature_options.explicit_namespace_prefixes?
        )

        self
      end

      # Returns whether any security configuration has been set.
      #
      # @return [Boolean] true if any security feature is configured
      #
      def configured?
        username_token? || timestamp? || signature?
      end

      # Returns whether UsernameToken is configured.
      #
      # @return [Boolean]
      #
      def username_token?
        !@username_token_config.nil?
      end

      # Returns whether Timestamp is configured.
      #
      # @return [Boolean]
      #
      def timestamp?
        !@timestamp_config.nil?
      end

      # Returns whether X.509 signing is configured.
      #
      # @return [Boolean]
      #
      def signature?
        !@signature_config.nil?
      end

      # Returns whether the SOAP body should be signed.
      #
      # @return [Boolean]
      #
      def sign_body?
        @signature_options&.sign_body? || false
      end

      # Returns whether the timestamp should be signed.
      #
      # @return [Boolean]
      #
      def sign_timestamp?
        (@signature_options&.sign_timestamp? && timestamp?) || false
      end

      # Returns whether WS-Addressing headers should be signed.
      #
      # When enabled, the following WS-Addressing headers will be signed
      # if present: To, From, ReplyTo, FaultTo, Action, MessageID, RelatesTo.
      #
      # This helps prevent routing attacks where an attacker could modify
      # the destination or action of a signed message.
      #
      # @return [Boolean]
      #
      def sign_addressing?
        @signature_options&.sign_addressing? || false
      end

      # Returns whether explicit namespace prefixes should be used.
      #
      # When enabled, XML elements use explicit prefixes like ds:Signature
      # instead of default namespaces. Some SOAP servers have strict XML
      # parsers that only accept prefixed elements.
      #
      # @return [Boolean]
      #
      def explicit_namespace_prefixes?
        @signature_options&.explicit_namespace_prefixes? || false
      end

      # Returns the key reference method for X.509 signing.
      #
      # @return [Symbol] one of :binary_security_token, :issuer_serial, :subject_key_identifier
      #
      def key_reference
        @signature_options&.key_reference || KeyRef::BINARY_SECURITY_TOKEN
      end

      # Enables response signature verification with optional certificate validation.
      #
      # When called without arguments, enables basic signature verification with
      # validity period checking (default). Add a trust_store to also validate
      # the certificate chain against trusted CAs.
      #
      # @param trust_store [OpenSSL::X509::Store, Symbol, String, Array, nil]
      #   Trust store for certificate chain validation:
      #   - `:system` — Use system default CA certificates
      #   - `String` — Path to CA bundle file or directory
      #   - `Array<OpenSSL::X509::Certificate>` — Array of trusted CA certificates
      #   - `OpenSSL::X509::Store` — Pre-configured certificate store
      #   - `nil` — Skip chain validation (default)
      # @param check_validity [Boolean] whether to check the certificate's validity
      #   period (not_before and not_after). Default: true
      # @param validate_timestamp [Boolean] whether to validate timestamp freshness
      #   to prevent replay attacks. Default: true
      # @param clock_skew [Integer] acceptable clock skew in seconds for timestamp
      #   validation. Default: 300 (5 minutes per WS-I BSP guidance)
      #
      # @return [self] for method chaining
      #
      # @example Basic verification (validity period and timestamp checked by default)
      #   config.verify_response
      #
      # @example With system CA validation
      #   config.verify_response(trust_store: :system)
      #
      # @example With custom CA certificates
      #   ca = OpenSSL::X509::Certificate.new(File.read('ca.pem'))
      #   config.verify_response(trust_store: [ca])
      #
      # @example Skip validity checking (not recommended)
      #   config.verify_response(check_validity: false)
      #
      # @example With custom clock skew tolerance
      #   config.verify_response(clock_skew: 600)  # 10 minutes
      #
      # @example Disable timestamp validation (not recommended)
      #   config.verify_response(validate_timestamp: false)
      #
      # @example Full chain with signature configuration
      #   config
      #     .timestamp
      #     .signature(certificate: cert, private_key: key)
      #     .verify_response(trust_store: :system)
      #
      def verify_response(trust_store: nil, check_validity: true, validate_timestamp: true, clock_skew: 300)
        @verify_response = true
        @verification_trust_store = trust_store
        @check_certificate_validity = check_validity
        @validate_timestamp = validate_timestamp
        @clock_skew = clock_skew
        self
      end

      # Sets whether response signature verification is enabled.
      #
      # This setter provides a simple way to enable/disable verification.
      # For configuration options, use {#verify_response} instead.
      #
      # @param value [Boolean] true to enable, false to disable
      #
      # @example
      #   config.verify_response = true
      #
      def verify_response=(value)
        @verify_response = value
        return if value

        # Reset options when disabled
        @verification_trust_store = nil
        @check_certificate_validity = true
        @validate_timestamp = true
        @clock_skew = 300
      end

      # Returns whether response signature verification is enabled.
      #
      # @return [Boolean]
      #
      def verify_response?
        @verify_response == true
      end

      # Returns a safe string representation that hides sensitive values.
      #
      # This method ensures that passwords, private keys, and other secrets
      # are never accidentally exposed in logs, error messages, debugger
      # output, or stack traces.
      #
      # @return [String] a redacted representation safe for logging
      #
      # @example
      #   config = Config.new
      #   config.username_token('admin', 'secret')
      #   config.inspect
      #   # => '#<WSDL::Security::Config username_token=true timestamp=false signature=false>'
      #
      def inspect
        parts = inspect_base_parts
        parts.concat(inspect_username_token_parts) if @username_token_config
        parts.concat(inspect_signature_parts) if @signature_config

        "#<#{self.class.name} #{parts.join(' ')}>"
      end

      # Clears all security configuration.
      #
      # @return [self] for method chaining
      #
      def clear
        @username_token_config = nil
        @timestamp_config = nil
        @signature_config = nil
        @signature_options = nil
        @verify_response = false
        self
      end

      # Creates a deep copy of this configuration.
      #
      # @return [Config] a new Config instance with the same settings
      #
      def dup
        copy = Config.new

        if @username_token_config
          copy.username_token(
            @username_token_config.username,
            @username_token_config.password,
            digest: @username_token_config.digest?
          )
        end

        if @timestamp_config
          copy.timestamp(
            expires_in: (@timestamp_config.expires_at - @timestamp_config.created_at).to_i
          )
        end

        if @signature_config && @signature_options
          copy.signature(
            certificate: @signature_config.certificate,
            private_key: @signature_config.private_key,
            **@signature_options.to_h
          )
        end

        if @verify_response
          copy.verify_response(
            trust_store: @verification_trust_store,
            check_validity: @check_certificate_validity,
            validate_timestamp: @validate_timestamp,
            clock_skew: @clock_skew
          )
        end

        copy
      end

      private

      def inspect_base_parts
        [
          "username_token=#{username_token?}",
          "timestamp=#{timestamp?}",
          "signature=#{signature?}",
          "verify_response=#{verify_response?}"
        ]
      end

      def inspect_username_token_parts
        [
          "username_token.username=#{@username_token_config.username.inspect}",
          'username_token.password=[REDACTED]',
          "username_token.digest=#{@username_token_config.digest?}"
        ]
      end

      def inspect_signature_parts
        cert_subject = @signature_config.certificate.subject.to_s rescue 'unknown' # rubocop:disable Style/RescueModifier
        [
          "signature.certificate=#{cert_subject.inspect}",
          'signature.private_key=[REDACTED]',
          "signature.algorithm=#{@signature_options&.digest_algorithm.inspect}"
        ]
      end

      # Normalizes certificate input to OpenSSL::X509::Certificate.
      #
      # @param certificate [OpenSSL::X509::Certificate, String] the certificate
      # @return [OpenSSL::X509::Certificate]
      #
      def normalize_certificate(certificate)
        case certificate
        when OpenSSL::X509::Certificate
          certificate
        when String
          OpenSSL::X509::Certificate.new(certificate)
        else
          raise ArgumentError, "Invalid certificate type: #{certificate.class}. " \
                               'Expected OpenSSL::X509::Certificate or PEM string.'
        end
      end

      # Normalizes private key input to OpenSSL::PKey.
      #
      # @param private_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC, String] the key
      # @param password [String, nil] password for encrypted key
      # @return [OpenSSL::PKey::RSA, OpenSSL::PKey::EC]
      #
      def normalize_private_key(private_key, password)
        case private_key
        when OpenSSL::PKey::RSA, OpenSSL::PKey::EC
          private_key
        when String
          OpenSSL::PKey.read(private_key, password)
        else
          raise ArgumentError, "Invalid private_key type: #{private_key.class}. " \
                               'Expected OpenSSL::PKey::RSA, OpenSSL::PKey::EC, or PEM string.'
        end
      end

      # Validates the key_reference option.
      #
      # @param key_reference [Symbol] the key reference method
      # @param certificate [OpenSSL::X509::Certificate] the certificate
      # @raise [ArgumentError] if the key_reference is invalid or incompatible
      #
      def validate_key_reference!(key_reference, certificate)
        valid_methods = [
          KeyRef::BINARY_SECURITY_TOKEN,
          KeyRef::ISSUER_SERIAL,
          KeyRef::SUBJECT_KEY_IDENTIFIER
        ]

        unless valid_methods.include?(key_reference)
          raise ArgumentError, "Invalid key_reference: #{key_reference.inspect}. " \
                               "Expected one of: #{valid_methods.map(&:inspect).join(', ')}"
        end

        # Raise if using SKI but certificate doesn't have the extension
        return unless key_reference == KeyRef::SUBJECT_KEY_IDENTIFIER

        ski = extract_subject_key_identifier(certificate)
        return unless ski.nil?

        raise ArgumentError, 'Cannot use :subject_key_identifier key reference: ' \
                             'certificate does not have a Subject Key Identifier extension'
      end

      # Extracts the Subject Key Identifier extension from a certificate.
      #
      # @param certificate [OpenSSL::X509::Certificate] the certificate
      # @return [String, nil] the SKI value or nil if not present
      #
      def extract_subject_key_identifier(certificate)
        certificate.extensions.each do |ext|
          if ext.oid == 'subjectKeyIdentifier'
            # The value is in the format "XX:XX:XX:..." - we want the raw hex
            return ext.value.delete(':')
          end
        end
        nil
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
