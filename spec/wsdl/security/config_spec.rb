# frozen_string_literal: true

RSpec.describe WSDL::Security::Config do
  subject(:config) { described_class.new }

  let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
  let(:certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Test Certificate']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  let(:certificate_with_ski) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Test Certificate with SKI']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600

    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = cert
    extension_factory.issuer_certificate = cert
    cert.add_extension(extension_factory.create_extension('subjectKeyIdentifier', 'hash', false))

    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  describe '#initialize' do
    it 'starts with no request security configured' do
      expect(config.configured?).to be(false)
      expect(config.username_token?).to be(false)
      expect(config.timestamp?).to be(false)
      expect(config.signature?).to be(false)

      context = config.request_context
      expect(context.username_token_config).to be_nil
      expect(context.timestamp_config).to be_nil
      expect(context.signature_config).to be_nil
    end

    it 'starts with disabled response verification' do
      expect(config.verify_response?).to be(false)
      expect(config.verification_mode).to eq(WSDL::Security::ResponsePolicy::MODE_DISABLED)
      expect(config.verification_trust_store).to be_nil
    end
  end

  describe '#username_token' do
    it 'configures username token and returns self' do
      expect(config.username_token('user', 'secret', digest: true)).to be(config)
      expect(config.username_token?).to be(true)
      expect(config.configured?).to be(true)
    end

    it 'materializes a fresh token for each request' do
      config.username_token('user', 'secret', digest: true)

      first = config.request_context(now: Time.utc(2026, 1, 1, 12, 0, 0)).username_token_config
      second = config.request_context(now: Time.utc(2026, 1, 1, 12, 1, 0)).username_token_config

      expect(first).to be_a(WSDL::Security::UsernameToken)
      expect(second).to be_a(WSDL::Security::UsernameToken)
      expect(first.created_at).not_to eq(second.created_at)
      expect(first.nonce).not_to eq(second.nonce)
    end

    it 'uses fixed created_at when provided' do
      created_at = Time.utc(2026, 2, 1, 8, 0, 0)
      config.username_token('user', 'secret', created_at:)

      context = config.request_context(now: Time.utc(2026, 2, 1, 9, 0, 0))
      expect(context.username_token_config.created_at).to eq(created_at)
    end
  end

  describe '#timestamp' do
    it 'configures timestamp and returns self' do
      expect(config.timestamp(expires_in: 600)).to be(config)
      expect(config.timestamp?).to be(true)
      expect(config.configured?).to be(true)
    end

    it 'materializes a fresh timestamp for each request' do
      config.timestamp(expires_in: 300)

      first = config.request_context(now: Time.utc(2026, 3, 1, 10, 0, 0)).timestamp_config
      second = config.request_context(now: Time.utc(2026, 3, 1, 10, 5, 0)).timestamp_config

      expect(first).to be_a(WSDL::Security::Timestamp)
      expect(second).to be_a(WSDL::Security::Timestamp)
      expect(first.created_at).not_to eq(second.created_at)
      expect(first.expires_at).to eq(Time.utc(2026, 3, 1, 10, 5, 0))
      expect(second.expires_at).to eq(Time.utc(2026, 3, 1, 10, 10, 0))
    end

    it 'honors explicit expires_at' do
      expires_at = Time.utc(2026, 3, 1, 12, 0, 0)
      config.timestamp(expires_at:)

      context = config.request_context(now: Time.utc(2026, 3, 1, 11, 0, 0))
      expect(context.timestamp_config.expires_at).to eq(expires_at)
    end
  end

  describe '#signature' do
    it 'configures signature behavior' do
      config.signature(
        certificate:,
        private_key:,
        digest_algorithm: :sha512,
        sign_timestamp: true,
        sign_addressing: true,
        explicit_namespace_prefixes: true,
        key_reference: :issuer_serial
      )

      expect(config.signature?).to be(true)
      expect(config.configured?).to be(true)
      expect(config.sign_timestamp?).to be(false)
      expect(config.sign_addressing?).to be(true)
      expect(config.explicit_namespace_prefixes?).to be(true)
      expect(config.key_reference).to eq(:issuer_serial)
    end

    it 'supports PEM credentials' do
      config.signature(certificate: certificate.to_pem, private_key: private_key.to_pem)

      runtime_signature = config.request_context.signature_config
      expect(runtime_signature.certificate).to be_a(OpenSSL::X509::Certificate)
      expect(runtime_signature.private_key).to be_a(OpenSSL::PKey::RSA)
    end

    it 'validates SKI key reference compatibility' do
      expect {
        config.signature(certificate:, private_key:, key_reference: :subject_key_identifier)
      }.to raise_error(ArgumentError, /Subject Key Identifier extension/)

      expect {
        config.signature(
          certificate: certificate_with_ski,
          private_key:,
          key_reference: :subject_key_identifier
        )
      }.not_to raise_error
    end

    it 'materializes a fresh runtime signature for each request' do
      config.signature(certificate:, private_key:)

      first = config.request_context.signature_config
      second = config.request_context.signature_config

      expect(first).to be_a(WSDL::Security::Signature)
      expect(second).to be_a(WSDL::Security::Signature)
      expect(first).not_to equal(second)
      expect(first.digest_algorithm).to eq(:sha256)
      expect(second.digest_algorithm).to eq(:sha256)
    end

    it 'raises for invalid credential input types' do
      expect {
        config.signature(certificate: 12_345, private_key:)
      }.to raise_error(ArgumentError, /Invalid certificate type/)

      expect {
        config.signature(certificate:, private_key: 12_345)
      }.to raise_error(ArgumentError, /Invalid private_key type/)
    end
  end

  describe '#verify_response' do
    it 'defaults strict mode to system trust store' do
      config.verify_response

      expect(config.verify_response?).to be(true)
      expect(config.verification_mode).to eq(WSDL::Security::ResponsePolicy::MODE_REQUIRED)
      expect(config.verification_trust_store).to eq(:system)
      expect(config.check_certificate_validity).to be(true)
      expect(config.validate_timestamp).to be(true)
      expect(config.clock_skew).to eq(300)
    end

    it 'allows explicit trust store in strict mode' do
      store = OpenSSL::X509::Store.new
      config.verify_response(mode: WSDL::Security::ResponsePolicy::MODE_REQUIRED, trust_store: store)

      expect(config.verification_trust_store).to eq(store)
    end

    it 'supports if_present mode without forcing trust store' do
      config.verify_response(
        mode: WSDL::Security::ResponsePolicy::MODE_IF_PRESENT,
        trust_store: nil,
        check_validity: false,
        validate_timestamp: false,
        clock_skew: 600
      )

      expect(config.verify_response?).to be(true)
      expect(config.verification_mode).to eq(WSDL::Security::ResponsePolicy::MODE_IF_PRESENT)
      expect(config.verification_trust_store).to be_nil
      expect(config.check_certificate_validity).to be(false)
      expect(config.validate_timestamp).to be(false)
      expect(config.clock_skew).to eq(600)
    end

    it 'supports disabled mode' do
      config.verify_response(mode: WSDL::Security::ResponsePolicy::MODE_DISABLED)

      expect(config.verify_response?).to be(false)
      expect(config.verification_mode).to eq(WSDL::Security::ResponsePolicy::MODE_DISABLED)
    end

    it 'raises for invalid mode' do
      expect {
        config.verify_response(mode: :legacy)
      }.to raise_error(ArgumentError, /Invalid response verification mode/)
    end

    it 'returns self for chaining' do
      expect(config.verify_response).to be(config)
    end
  end

  describe '#response_policy' do
    it 'returns the response policy' do
      expect(config.response_policy).to be_a(WSDL::Security::ResponsePolicy)
      expect(config.response_policy.mode).to eq(WSDL::Security::ResponsePolicy::MODE_DISABLED)
    end

    it 'reflects verify_response configuration' do
      config.verify_response(mode: WSDL::Security::ResponsePolicy::MODE_REQUIRED)

      expect(config.response_policy.mode).to eq(WSDL::Security::ResponsePolicy::MODE_REQUIRED)
    end
  end

  describe '#clear' do
    it 'resets request and response policies' do
      config
        .username_token('user', 'pass')
        .timestamp
        .signature(certificate:, private_key:, sign_addressing: true)
        .verify_response

      config.clear

      expect(config.configured?).to be(false)
      expect(config.verify_response?).to be(false)
      expect(config.key_reference).to eq(:binary_security_token)

      context = config.request_context
      expect(context.username_token_config).to be_nil
      expect(context.timestamp_config).to be_nil
      expect(context.signature_config).to be_nil
    end

    it 'returns self' do
      expect(config.clear).to be(config)
    end
  end

  describe '#dup' do
    it 'copies configuration and remains independent' do
      config
        .username_token('user', 'pass', digest: true)
        .timestamp(expires_in: 600)
        .signature(certificate:, private_key:, sign_addressing: true)
        .verify_response(mode: WSDL::Security::ResponsePolicy::MODE_IF_PRESENT, clock_skew: 100)

      copy = config.dup

      expect(copy).not_to equal(config)
      expect(copy.configured?).to be(true)
      expect(copy.verification_mode).to eq(config.verification_mode)
      expect(copy.clock_skew).to eq(100)

      copy.clear
      expect(copy.configured?).to be(false)
      expect(config.configured?).to be(true)
    end
  end

  describe '#inspect' do
    it 'shows base flags for unconfigured config' do
      output = config.inspect

      expect(output).to include('WSDL::Security::Config')
      expect(output).to include('username_token=false')
      expect(output).to include('timestamp=false')
      expect(output).to include('signature=false')
      expect(output).to include('verify_response=false')
      expect(output).to include('verify_mode=:disabled')
    end

    it 'includes signature details with certificate subject' do
      config.signature(certificate:, private_key:, digest_algorithm: :sha512)
      output = config.inspect

      expect(output).to include('signature=true')
      expect(output).to include('signature.certificate="/CN=Test Certificate"')
      expect(output).to include('signature.private_key=[REDACTED]')
      expect(output).to include('signature.algorithm=:sha512')
    end

    it 'redacts secrets and keeps useful metadata' do
      config
        .username_token('admin', 'super-secret', digest: true)
        .signature(certificate:, private_key:, digest_algorithm: :sha256)
        .verify_response

      output = config.inspect

      expect(output).to include('WSDL::Security::Config')
      expect(output).to include('username_token=true')
      expect(output).to include('signature=true')
      expect(output).to include('verify_response=true')
      expect(output).to include('username_token.username="admin"')
      expect(output).to include('username_token.password=[REDACTED]')
      expect(output).to include('signature.private_key=[REDACTED]')
      expect(output).not_to include('super-secret')
      expect(output).not_to include(private_key.to_pem)
    end
  end
end
