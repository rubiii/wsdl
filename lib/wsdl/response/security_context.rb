# frozen_string_literal: true

module WSDL
  class Response
    # Encapsulates security verification for SOAP responses.
    #
    # This class handles signature verification, certificate validation, and
    # timestamp freshness checking as a unified security context. It provides
    # a clean API for verifying that a SOAP response is authentic and fresh.
    #
    # @example Basic signature verification
    #   response = operation.call
    #   if response.security.signature_valid?
    #     puts "Response is signed and valid"
    #   else
    #     puts "Errors: #{response.security.errors}"
    #   end
    #
    # @example Combined verification (signature + timestamp)
    #   response = operation.call
    #   if response.security.valid?
    #     puts "Response is secure"
    #   end
    #
    # @example Strict verification with exceptions
    #   begin
    #     response.security.verify!
    #   rescue WSDL::SignatureVerificationError => e
    #     puts "Signature error: #{e.message}"
    #   rescue WSDL::TimestampValidationError => e
    #     puts "Timestamp error: #{e.message}"
    #   end
    #
    # @see WSDL::Security::Verifier
    #
    class SecurityContext
      # Creates a new SecurityContext instance.
      #
      # @param document [Nokogiri::XML::Document] the parsed SOAP response
      # @param verification [Security::ResponseVerification] verification options
      #   for certificate and timestamp validation
      # @param certificate [OpenSSL::X509::Certificate, nil] optional certificate
      #   to use for verification instead of extracting from message
      #
      def initialize(document, verification = Security::ResponseVerification::Options.default, certificate: nil)
        @document = document
        @verification = verification
        @certificate = certificate
        @verifier = nil
      end

      # ============================================================
      # Combined Verification
      # ============================================================

      # Returns whether the response passes all security checks.
      #
      # This performs combined verification of:
      # - Signature (if present)
      # - Timestamp freshness (if enabled and present)
      #
      # @return [Boolean] true if all security checks pass
      #
      def valid?
        return false unless signature_present?

        verifier.valid?
      end

      # Verifies the response and raises an error if any check fails.
      #
      # This performs combined verification of signature and timestamp,
      # raising the appropriate error type for the first failure encountered.
      #
      # @raise [SignatureVerificationError] if signature is missing or invalid
      # @raise [TimestampValidationError] if timestamp validation fails
      # @return [true] if all checks pass
      #
      def verify! # rubocop:disable Naming/PredicateMethod
        verify_signature!
        verify_timestamp!
        true
      end

      # ============================================================
      # Signature Verification
      # ============================================================

      # Returns whether the response contains a signature.
      #
      # @return [Boolean] true if a ds:Signature element is present
      #
      def signature_present?
        verifier.signature_present?
      end

      # Returns whether the response signature is valid.
      #
      # This performs full signature verification including:
      # - Locating the signing certificate (from BinarySecurityToken or provided)
      # - Verifying all Reference digests match the signed elements
      # - Verifying the SignatureValue over the canonicalized SignedInfo
      #
      # Returns false if no signature is present. Use {#signature_present?}
      # to distinguish between "no signature" and "invalid signature".
      #
      # @return [Boolean] true if signature is present and valid
      #
      def signature_valid?
        return false unless signature_present?

        # Run verification but only check signature-related phases
        # (timestamp validation is separate)
        verifier_without_timestamp.valid?
      end

      # Verifies the signature and raises an error if invalid.
      #
      # @raise [SignatureVerificationError] if signature is missing or invalid
      # @return [true] if signature is valid
      #
      def verify_signature!
        raise SignatureVerificationError, 'Response does not contain a signature' unless signature_present?

        unless signature_valid?
          sig_errors = verifier_without_timestamp.errors.join('; ')
          raise SignatureVerificationError, "Signature verification failed: #{sig_errors}"
        end

        true
      end

      # Returns the IDs of all signed elements.
      #
      # @return [Array<String>] element IDs (e.g., ['Body-abc123', 'Timestamp-xyz789'])
      #
      def signed_element_ids
        verifier.signed_element_ids
      end

      # Returns the names of all signed elements.
      #
      # @return [Array<String>] element names (e.g., ['Body', 'Timestamp'])
      #
      def signed_elements
        verifier.signed_elements
      end

      # Returns the signature algorithm used.
      #
      # @return [String, nil] the algorithm URI
      #
      def signature_algorithm
        verifier.signature_algorithm
      end

      # Returns the digest algorithm used.
      #
      # @return [String, nil] the algorithm URI from the first reference
      #
      def digest_algorithm
        verifier.digest_algorithm
      end

      # Returns the certificate used to sign the response.
      #
      # @return [OpenSSL::X509::Certificate, nil] the signing certificate
      #
      def signing_certificate
        # Trigger verification to extract certificate
        verifier.valid? unless verifier.certificate
        verifier.certificate
      end

      # ============================================================
      # Timestamp Verification
      # ============================================================

      # Returns whether the response contains a timestamp.
      #
      # @return [Boolean] true if wsu:Timestamp exists in the Security header
      #
      def timestamp_present?
        verifier.timestamp_present?
      end

      # Returns whether the response timestamp is valid (fresh).
      #
      # Returns true if:
      # - Timestamp validation is disabled
      # - No timestamp is present (timestamps are optional per spec)
      # - Timestamp is present and within acceptable time bounds
      #
      # @return [Boolean] true if timestamp is valid or not present
      #
      def timestamp_valid?
        return true unless @verification.timestamp.validate

        verifier.timestamp_valid?
      end

      # Verifies the timestamp and raises an error if invalid.
      #
      # @raise [TimestampValidationError] if timestamp validation fails
      # @return [true] if timestamp is valid
      #
      def verify_timestamp! # rubocop:disable Naming/PredicateMethod
        return true unless @verification.timestamp.validate
        return true unless timestamp_present?

        unless verifier.timestamp_valid?
          # Get timestamp-specific errors
          ts_validator = Security::Verifier::TimestampValidator.new(
            @document,
            clock_skew: @verification.timestamp.tolerance_seconds
          )
          ts_validator.valid?
          ts_errors = ts_validator.errors.join('; ')
          raise TimestampValidationError, "Timestamp validation failed: #{ts_errors}"
        end

        true
      end

      # Returns the parsed timestamp information.
      #
      # @return [Hash, nil] hash with :created_at and :expires_at keys,
      #   or nil if no timestamp present
      #
      def timestamp
        verifier.timestamp
      end

      # ============================================================
      # Error Information
      # ============================================================

      # Returns all errors from security verification.
      #
      # This includes errors from both signature and timestamp validation.
      #
      # @return [Array<String>] error messages
      #
      def errors
        verifier.errors
      end

      private

      # Returns the main verifier instance (with timestamp validation).
      #
      # @return [Security::Verifier]
      #
      def verifier
        @verifier ||= Security::Verifier.new(
          @document,
          certificate: @certificate,
          trust_store: @verification.certificate.trust_store,
          check_validity: @verification.certificate.verify_not_expired,
          validate_timestamp: @verification.timestamp.validate,
          clock_skew: @verification.timestamp.tolerance_seconds
        )
      end

      # Returns a verifier instance without timestamp validation.
      #
      # Used for signature-only validation.
      #
      # @return [Security::Verifier]
      #
      def verifier_without_timestamp
        @verifier_without_timestamp ||= Security::Verifier.new(
          @document,
          certificate: @certificate,
          trust_store: @verification.certificate.trust_store,
          check_validity: @verification.certificate.verify_not_expired,
          validate_timestamp: false
        )
      end
    end
  end
end
