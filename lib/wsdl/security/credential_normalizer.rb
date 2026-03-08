# frozen_string_literal: true

require 'openssl'

module WSDL
  module Security
    # Normalizes and validates signing credentials.
    class CredentialNormalizer
      # Local alias for key reference constants
      KeyRef = Constants::KeyReference

      # @param certificate [OpenSSL::X509::Certificate, String]
      # @return [OpenSSL::X509::Certificate]
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

      # @param private_key [OpenSSL::PKey::RSA, OpenSSL::PKey::EC, String]
      # @param password [String, nil]
      # @return [OpenSSL::PKey::RSA, OpenSSL::PKey::EC]
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

      # @param key_reference [Symbol]
      # @param certificate [OpenSSL::X509::Certificate]
      # @return [void]
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

        return unless key_reference == KeyRef::SUBJECT_KEY_IDENTIFIER
        return if subject_key_identifier?(certificate)

        raise ArgumentError, 'Cannot use :subject_key_identifier key reference: ' \
                             'certificate does not have a Subject Key Identifier extension'
      end

      private

      # @param certificate [OpenSSL::X509::Certificate]
      # @return [Boolean]
      def subject_key_identifier?(certificate)
        certificate.extensions.any? { |ext| ext.oid == 'subjectKeyIdentifier' }
      end
    end
  end
end
