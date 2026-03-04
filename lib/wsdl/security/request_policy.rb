# frozen_string_literal: true

module WSDL
  module Security
    # Immutable request-side WS-Security policy.
    #
    # This policy captures what should be applied to outgoing requests,
    # but does not hold per-request runtime artifacts (IDs, nonce, timestamps).
    # Runtime objects are created by {RequestMaterializer} for each call.
    class RequestPolicy
      # Immutable UsernameToken request policy.
      UsernameToken = Data.define(:username, :password, :digest, :created_at)

      # Immutable timestamp request policy.
      Timestamp = Data.define(:created_at, :expires_in, :expires_at)

      # Immutable signature request policy.
      Signature = Data.define(:certificate, :private_key, :options)

      # Creates an empty request policy.
      #
      # @return [RequestPolicy]
      #
      def self.empty
        new
      end

      # @param username_token [UsernameToken, nil]
      # @param timestamp [Timestamp, nil]
      # @param signature [Signature, nil]
      def initialize(username_token: nil, timestamp: nil, signature: nil)
        @username_token = username_token
        @timestamp = timestamp
        @signature = signature
        freeze
      end

      # @return [UsernameToken, nil]
      attr_reader :username_token

      # @return [Timestamp, nil]
      attr_reader :timestamp

      # @return [Signature, nil]
      attr_reader :signature

      # @param username_token [UsernameToken, nil]
      # @return [RequestPolicy]
      def with_username_token(username_token)
        self.class.new(username_token:, timestamp: @timestamp, signature: @signature)
      end

      # @param timestamp [Timestamp, nil]
      # @return [RequestPolicy]
      def with_timestamp(timestamp)
        self.class.new(username_token: @username_token, timestamp:, signature: @signature)
      end

      # @param signature [Signature, nil]
      # @return [RequestPolicy]
      def with_signature(signature)
        self.class.new(username_token: @username_token, timestamp: @timestamp, signature:)
      end

      # @return [Boolean]
      def configured?
        username_token? || timestamp? || signature?
      end

      # @return [Boolean]
      def username_token?
        !@username_token.nil?
      end

      # @return [Boolean]
      def timestamp?
        !@timestamp.nil?
      end

      # @return [Boolean]
      def signature?
        !@signature.nil?
      end

      # @return [Boolean]
      def sign_timestamp?
        (@signature&.options&.sign_timestamp? && timestamp?) || false
      end

      # @return [Boolean]
      def sign_addressing?
        @signature&.options&.sign_addressing? || false
      end

      # @return [Boolean]
      def explicit_namespace_prefixes?
        @signature&.options&.explicit_namespace_prefixes? || false
      end

      # @return [Symbol]
      def key_reference
        @signature&.options&.key_reference || Constants::KeyReference::BINARY_SECURITY_TOKEN
      end
    end
  end
end
