# frozen_string_literal: true

module WSDL
  module Security
    # Per-request runtime security context.
    #
    # This object contains generated UsernameToken/Timestamp/Signature
    # instances that must not be reused across calls.
    class RequestContext
      # @param username_token_config [UsernameToken, nil]
      # @param timestamp_config [Timestamp, nil]
      # @param signature_config [Signature, nil]
      # @param signature_options [SignatureOptions, nil]
      def initialize(username_token_config:, timestamp_config:, signature_config:, signature_options:)
        @username_token_config = username_token_config
        @timestamp_config = timestamp_config
        @signature_config = signature_config
        @signature_options = signature_options
      end

      # @return [UsernameToken, nil]
      attr_reader :username_token_config

      # @return [Timestamp, nil]
      attr_reader :timestamp_config

      # @return [Signature, nil]
      attr_reader :signature_config

      # @return [Boolean]
      def configured?
        username_token? || timestamp? || signature?
      end

      # @return [Boolean]
      def username_token?
        !@username_token_config.nil?
      end

      # @return [Boolean]
      def timestamp?
        !@timestamp_config.nil?
      end

      # @return [Boolean]
      def signature?
        !@signature_config.nil?
      end

      # @return [Boolean]
      def sign_body?
        @signature_options&.sign_body? || false
      end

      # @return [Boolean]
      def sign_timestamp?
        (@signature_options&.sign_timestamp? && timestamp?) || false
      end

      # @return [Boolean]
      def sign_addressing?
        @signature_options&.sign_addressing? || false
      end

      # @return [Boolean]
      def explicit_namespace_prefixes?
        @signature_options&.explicit_namespace_prefixes? || false
      end

      # @return [Symbol]
      def key_reference
        @signature_options&.key_reference || Constants::KeyReference::BINARY_SECURITY_TOKEN
      end
    end
  end
end
