# frozen_string_literal: true

RSpec.describe WSDL::Security::RequestMaterializer do
  let(:now) { Time.utc(2026, 3, 8, 12, 0, 0) }

  let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
  let(:certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([%w[CN Test]])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  describe '.materialize' do
    context 'with an empty policy' do
      it 'returns a RequestContext with all nil configs' do
        policy = WSDL::Security::RequestPolicy.empty
        context = described_class.materialize(policy, now:)

        expect(context).to be_a(WSDL::Security::RequestContext)
        expect(context.username_token_config).to be_nil
        expect(context.timestamp_config).to be_nil
        expect(context.signature_config).to be_nil
        expect(context).not_to be_configured
      end
    end

    context 'with a username token policy' do
      it 'builds a UsernameToken from the policy' do
        ut_policy = WSDL::Security::RequestPolicy::UsernameToken.new(
          username: 'alice',
          password: 's3cret',
          digest: true,
          created_at: nil
        )
        policy = WSDL::Security::RequestPolicy.new(username_token: ut_policy)

        context = described_class.materialize(policy, now:)
        token = context.username_token_config

        expect(token).to be_a(WSDL::Security::UsernameToken)
        expect(token.username).to eq('alice')
        expect(context).to be_configured
      end

      it 'uses the policy created_at when provided' do
        custom_time = Time.utc(2026, 1, 1, 0, 0, 0)
        ut_policy = WSDL::Security::RequestPolicy::UsernameToken.new(
          username: 'alice',
          password: 's3cret',
          digest: false,
          created_at: custom_time
        )
        policy = WSDL::Security::RequestPolicy.new(username_token: ut_policy)

        context = described_class.materialize(policy, now:)
        expect(context.username_token_config.created_at).to eq(custom_time)
      end

      it 'falls back to now when created_at is nil' do
        ut_policy = WSDL::Security::RequestPolicy::UsernameToken.new(
          username: 'alice',
          password: 's3cret',
          digest: false,
          created_at: nil
        )
        policy = WSDL::Security::RequestPolicy.new(username_token: ut_policy)

        context = described_class.materialize(policy, now:)
        expect(context.username_token_config.created_at).to eq(now)
      end
    end

    context 'with a timestamp policy' do
      it 'builds a Timestamp from the policy' do
        ts_policy = WSDL::Security::RequestPolicy::Timestamp.new(
          created_at: nil,
          expires_in: 600,
          expires_at: nil
        )
        policy = WSDL::Security::RequestPolicy.new(timestamp: ts_policy)

        context = described_class.materialize(policy, now:)
        timestamp = context.timestamp_config

        expect(timestamp).to be_a(WSDL::Security::Timestamp)
        expect(timestamp.created_at).to eq(now)
        expect(context).to be_configured
      end

      it 'uses the policy created_at when provided' do
        custom_time = Time.utc(2026, 1, 1, 0, 0, 0)
        ts_policy = WSDL::Security::RequestPolicy::Timestamp.new(
          created_at: custom_time,
          expires_in: 300,
          expires_at: nil
        )
        policy = WSDL::Security::RequestPolicy.new(timestamp: ts_policy)

        context = described_class.materialize(policy, now:)
        expect(context.timestamp_config.created_at).to eq(custom_time)
      end

      it 'uses expires_at when provided' do
        expires = Time.utc(2026, 3, 8, 13, 0, 0)
        ts_policy = WSDL::Security::RequestPolicy::Timestamp.new(
          created_at: nil,
          expires_in: nil,
          expires_at: expires
        )
        policy = WSDL::Security::RequestPolicy.new(timestamp: ts_policy)

        context = described_class.materialize(policy, now:)
        expect(context.timestamp_config.expires_at).to eq(expires)
      end
    end

    context 'with a signature policy' do
      let(:signature_options) do
        WSDL::Security::SignatureOptions.from_hash(
          digest_algorithm: :sha256,
          key_reference: :issuer_serial,
          explicit_namespace_prefixes: true
        )
      end

      it 'builds a Signature from the policy' do
        sig_policy = WSDL::Security::RequestPolicy::Signature.new(
          certificate:,
          private_key:,
          options: signature_options
        )
        policy = WSDL::Security::RequestPolicy.new(signature: sig_policy)

        context = described_class.materialize(policy, now:)

        expect(context.signature_config).to be_a(WSDL::Security::Signature)
        expect(context).to be_configured
      end

      it 'passes signature options through to the context' do
        sig_policy = WSDL::Security::RequestPolicy::Signature.new(
          certificate:,
          private_key:,
          options: signature_options
        )
        policy = WSDL::Security::RequestPolicy.new(signature: sig_policy)

        context = described_class.materialize(policy, now:)

        expect(context).to be_explicit_namespace_prefixes
        expect(context.key_reference).to eq(:issuer_serial)
      end
    end

    context 'with all policies combined' do
      it 'materializes all three components' do
        ut_policy = WSDL::Security::RequestPolicy::UsernameToken.new(
          username: 'alice', password: 's3cret', digest: true, created_at: nil
        )
        ts_policy = WSDL::Security::RequestPolicy::Timestamp.new(
          created_at: nil, expires_in: 300, expires_at: nil
        )
        sig_options = WSDL::Security::SignatureOptions.from_hash(digest_algorithm: :sha256)
        sig_policy = WSDL::Security::RequestPolicy::Signature.new(
          certificate:, private_key:, options: sig_options
        )

        policy = WSDL::Security::RequestPolicy.new(
          username_token: ut_policy,
          timestamp: ts_policy,
          signature: sig_policy
        )

        context = described_class.materialize(policy, now:)

        expect(context.username_token_config).to be_a(WSDL::Security::UsernameToken)
        expect(context.timestamp_config).to be_a(WSDL::Security::Timestamp)
        expect(context.signature_config).to be_a(WSDL::Security::Signature)
      end
    end
  end
end
