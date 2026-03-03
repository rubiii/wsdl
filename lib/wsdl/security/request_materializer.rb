# frozen_string_literal: true

module WSDL
  module Security
    # Builds per-request runtime security objects from immutable request policy.
    class RequestMaterializer
      # @param policy [RequestPolicy]
      # @param now [Time]
      # @return [RequestContext]
      def self.materialize(policy, now: Time.now.utc)
        username_token = build_username_token(policy.username_token, now: now)
        timestamp = build_timestamp(policy.timestamp, now: now)

        signature_policy = policy.signature
        signature_options = signature_policy&.options
        signature = build_signature(signature_policy)

        RequestContext.new(
          username_token_config: username_token,
          timestamp_config: timestamp,
          signature_config: signature,
          signature_options: signature_options
        )
      end

      # @param username_policy [RequestPolicy::UsernameToken, nil]
      # @param now [Time]
      # @return [UsernameToken, nil]
      def self.build_username_token(username_policy, now:)
        return nil unless username_policy

        UsernameToken.new(
          username_policy.username,
          username_policy.password,
          digest: username_policy.digest,
          created_at: username_policy.created_at || now
        )
      end
      private_class_method :build_username_token

      # @param timestamp_policy [RequestPolicy::Timestamp, nil]
      # @param now [Time]
      # @return [Timestamp, nil]
      def self.build_timestamp(timestamp_policy, now:)
        return nil unless timestamp_policy

        Timestamp.new(
          created_at: timestamp_policy.created_at || now,
          expires_in: timestamp_policy.expires_in,
          expires_at: timestamp_policy.expires_at
        )
      end
      private_class_method :build_timestamp

      # @param signature_policy [RequestPolicy::Signature, nil]
      # @return [Signature, nil]
      def self.build_signature(signature_policy)
        return nil unless signature_policy

        Signature.new(
          certificate: signature_policy.certificate,
          private_key: signature_policy.private_key,
          digest_algorithm: signature_policy.options.digest_algorithm,
          key_reference: signature_policy.options.key_reference,
          explicit_namespace_prefixes: signature_policy.options.explicit_namespace_prefixes?
        )
      end
      private_class_method :build_signature
    end
  end
end
