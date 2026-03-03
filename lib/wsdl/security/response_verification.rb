# frozen_string_literal: true

module WSDL
  module Security
    # Immutable configuration objects for SOAP response security verification.
    #
    # This namespace groups certificate and timestamp verification options used
    # by response signature verification.
    module ResponseVerification
      # Certificate chain and validity verification options.
      #
      # @!attribute [r] trust_store
      #   Trust store for certificate chain validation.
      #   @return [OpenSSL::X509::Store, Symbol, String, Array, nil]
      #     - `nil` — No chain validation (default)
      #     - `:system` — Use system CA certificates
      #     - `String` — Path to CA certificate file or directory
      #     - `Array` — Array of certificate objects or PEM strings
      #     - `OpenSSL::X509::Store` — Pre-configured trust store
      #
      # @!attribute [r] verify_not_expired
      #   Whether to check the certificate's validity period (not_before/not_after).
      #   @return [Boolean] true to verify certificate is not expired (default: true)
      #
      Certificate = Data.define(:trust_store, :verify_not_expired) {
        # Returns default certificate verification options.
        #
        # @return [Certificate] defaults with no trust store and expiration checking enabled
        #
        def self.default
          new(trust_store: nil, verify_not_expired: true)
        end
      }

      # Timestamp freshness verification options.
      #
      # WS-Security timestamps contain Created and Expires times that can be
      # validated to prevent replay attacks and ensure message freshness.
      #
      # @!attribute [r] validate
      #   Whether to validate timestamp freshness.
      #   @return [Boolean] true to validate timestamps (default: true)
      #
      # @!attribute [r] tolerance_seconds
      #   Acceptable clock skew tolerance in seconds.
      #   Allows for minor time differences between client and server clocks.
      #   @return [Integer] tolerance in seconds (default: 300, per WS-I BSP guidance)
      #
      Timestamp = Data.define(:validate, :tolerance_seconds) {
        # Returns default timestamp verification options.
        #
        # @return [Timestamp] defaults with validation enabled and 5-minute tolerance
        #
        def self.default
          new(validate: true, tolerance_seconds: 300)
        end
      }

      # Immutable configuration for response signature and timestamp verification.
      #
      # This Data class encapsulates all options needed to verify signed SOAP responses,
      # organized into logical groups for certificate and timestamp verification.
      #
      # @!attribute [r] certificate
      #   Certificate verification options.
      #   @return [Certificate]
      #
      # @!attribute [r] timestamp
      #   Timestamp verification options.
      #   @return [Timestamp]
      #
      # @example Using defaults
      #   verification = ResponseVerification::Options.default
      #
      # @example Creating from Security::Config
      #   verification = ResponseVerification::Options.from_config(security_config)
      #
      # @example Custom configuration
      #   verification = ResponseVerification::Options.new(
      #     certificate: ResponseVerification::Certificate.new(
      #       trust_store: :system,
      #       verify_not_expired: true
      #     ),
      #     timestamp: ResponseVerification::Timestamp.new(
      #       validate: true,
      #       tolerance_seconds: 600
      #     )
      #   )
      #
      # @example Accessing nested options
      #   verification.certificate.trust_store        # => :system
      #   verification.certificate.verify_not_expired # => true
      #   verification.timestamp.validate             # => true
      #   verification.timestamp.tolerance_seconds    # => 300
      #
      Options = Data.define(:certificate, :timestamp) {
        # Returns default response verification options.
        #
        # @return [Options] defaults for both certificate and timestamp
        #
        def self.default
          new(certificate: Certificate.default, timestamp: Timestamp.default)
        end

        # Creates verification options from a Security::Config instance.
        #
        # @param config [Security::Config] the security configuration
        # @return [Options] verification options extracted from config
        #
        def self.from_config(config)
          return config.response_verification_options if config.respond_to?(:response_verification_options)

          new(
            certificate: Certificate.new(
              trust_store: config.verification_trust_store,
              verify_not_expired: config.check_certificate_validity
            ),
            timestamp: Timestamp.new(
              validate: config.validate_timestamp,
              tolerance_seconds: config.clock_skew
            )
          )
        end
      }
    end
  end
end
