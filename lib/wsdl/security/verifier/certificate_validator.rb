# frozen_string_literal: true

require_relative 'base'

module WSDL
  module Security
    class Verifier
      # Validates X.509 certificates for trust and validity.
      #
      # This class performs two types of validation:
      #
      # - *Validity period* — Checks the certificate is not expired and not yet valid
      # - *Chain validation* — Verifies the certificate chain against a trust store
      #
      # Validity period checking is enabled by default and runs first (fast, no I/O).
      # Chain validation only runs if a trust store is provided.
      #
      # @example Basic validity checking (default)
      #   validator = CertificateValidator.new(certificate)
      #   validator.valid?  # Checks validity period only
      #
      # @example With system CA trust store
      #   validator = CertificateValidator.new(certificate, trust_store: :system)
      #   validator.valid?  # Checks validity + chain against system CAs
      #
      # @example With custom CA certificates
      #   validator = CertificateValidator.new(
      #     certificate,
      #     trust_store: [ca_cert]
      #   )
      #   validator.valid?
      #
      # @example Skip validity checking (not recommended)
      #   validator = CertificateValidator.new(
      #     certificate,
      #     trust_store: :system,
      #     check_validity: false
      #   )
      #
      class CertificateValidator < Base
        # Creates a new certificate validator.
        #
        # @param certificate [OpenSSL::X509::Certificate] the certificate to validate
        # @param trust_store [OpenSSL::X509::Store, Symbol, String, Array, nil] trust store
        #   for chain validation:
        #   - `:system` — Use system default CA certificates
        #   - `String` — Path to CA bundle file or directory
        #   - `Array<OpenSSL::X509::Certificate>` — Array of trusted CA certificates
        #   - `OpenSSL::X509::Store` — Pre-configured certificate store
        #   - `nil` — Skip chain validation (default)
        # @param check_validity [Boolean] whether to check the certificate's validity
        #   period (not_before and not_after). Default: true
        # @param at_time [Time, nil] time to use for validation. Useful for testing
        #   or verifying messages received in the past. Default: current time
        def initialize(certificate, trust_store: nil, check_validity: true, at_time: nil)
          super()
          @certificate = certificate
          @trust_store = trust_store
          @check_validity = check_validity
          @at_time = at_time || Time.now
        end

        # Validates the certificate.
        #
        # Runs validity period checking first (if enabled), then chain validation
        # (if a trust store is configured). Returns false on the first failure.
        #
        # @return [Boolean] true if all enabled checks pass
        def valid?
          # Validity period first (fast, no I/O)
          return false if @check_validity && !validate_validity_period

          # Chain validation (if trust store configured)
          return false if @trust_store && !validate_chain

          true
        end

        private

        # Validates the certificate is within its validity period.
        #
        # @return [Boolean] true if certificate is currently valid
        def validate_validity_period
          if @at_time < @certificate.not_before
            return add_failure(
              "Certificate is not yet valid (valid from #{format_time(@certificate.not_before)})"
            )
          end

          if @at_time > @certificate.not_after
            return add_failure(
              "Certificate has expired (expired #{format_time(@certificate.not_after)})"
            )
          end

          true
        end

        # Validates the certificate chain against the trust store.
        #
        # @return [Boolean] true if chain validates successfully
        def validate_chain
          store = build_store
          store.time = @at_time

          return true if store.verify(@certificate)

          add_failure("Certificate chain validation failed: #{store.error_string}")
        end

        # Builds an OpenSSL::X509::Store from the trust_store option.
        #
        # @return [OpenSSL::X509::Store] the configured store
        # @raise [ArgumentError] if trust_store type is invalid
        def build_store
          case @trust_store
          when OpenSSL::X509::Store
            @trust_store
          when :system
            build_system_store
          when String
            build_file_store(@trust_store)
          when Array
            build_array_store(@trust_store)
          else
            raise ArgumentError, "Invalid trust_store: #{@trust_store.class}. " \
                                 'Expected :system, path String, Certificate Array, or OpenSSL::X509::Store'
          end
        end

        # Builds a store using system default CA certificates.
        #
        # @return [OpenSSL::X509::Store]
        def build_system_store
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          store
        end

        # Builds a store from a file or directory path.
        #
        # @param path [String] path to CA bundle file or directory
        # @return [OpenSSL::X509::Store]
        def build_file_store(path)
          store = OpenSSL::X509::Store.new

          if File.directory?(path)
            store.add_path(path)
          else
            store.add_file(path)
          end

          store
        end

        # Builds a store from an array of certificates.
        #
        # @param certificates [Array<OpenSSL::X509::Certificate>] trusted CA certificates
        # @return [OpenSSL::X509::Store]
        def build_array_store(certificates)
          store = OpenSSL::X509::Store.new
          certificates.each do |cert|
            store.add_cert(cert)
          end
          store
        end

        # Formats a time for display in error messages.
        #
        # @param time [Time] the time to format
        # @return [String] ISO 8601 formatted time in UTC
        def format_time(time)
          time.utc.iso8601
        end
      end
    end
  end
end
