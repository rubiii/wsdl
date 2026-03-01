# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::Config do
  # Generate a self-signed certificate and key for testing
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
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

  # Certificate with Subject Key Identifier extension
  let(:certificate_with_ski) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Test Certificate with SKI']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600

    # Add Subject Key Identifier extension
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))

    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  describe '#initialize' do
    subject(:config) { described_class.new }

    it 'has no username_token_config' do
      expect(config.username_token_config).to be_nil
    end

    it 'has no timestamp_config' do
      expect(config.timestamp_config).to be_nil
    end

    it 'has no signature_config' do
      expect(config.signature_config).to be_nil
    end

    it 'is not configured' do
      expect(config.configured?).to be false
    end

    it 'has verify_response disabled' do
      expect(config.verify_response?).to be false
    end
  end

  describe '#username_token' do
    subject(:config) { described_class.new }

    context 'with plain text mode' do
      before do
        config.username_token('user', 'secret')
      end

      it 'creates a UsernameToken config' do
        expect(config.username_token_config).to be_a(WSDL::Security::UsernameToken)
      end

      it 'sets the username' do
        expect(config.username_token_config.username).to eq('user')
      end

      it 'sets the password' do
        expect(config.username_token_config.password).to eq('secret')
      end

      it 'uses plain text mode by default' do
        expect(config.username_token_config.digest?).to be false
      end

      it 'marks config as configured' do
        expect(config.configured?).to be true
      end

      it 'returns self for method chaining' do
        new_config = described_class.new
        expect(new_config.username_token('u', 'p')).to eq(new_config)
      end
    end

    context 'with digest mode' do
      before do
        config.username_token('user', 'secret', digest: true)
      end

      it 'enables digest mode' do
        expect(config.username_token_config.digest?).to be true
      end
    end

    context 'with custom created_at' do
      let(:custom_time) { Time.utc(2026, 1, 15, 10, 0, 0) }

      before do
        config.username_token('user', 'secret', created_at: custom_time)
      end

      it 'uses the provided created_at time' do
        expect(config.username_token_config.created_at).to eq(custom_time)
      end
    end
  end

  describe '#timestamp' do
    subject(:config) { described_class.new }

    context 'with default options' do
      before do
        config.timestamp
      end

      it 'creates a Timestamp config' do
        expect(config.timestamp_config).to be_a(WSDL::Security::Timestamp)
      end

      it 'uses default TTL' do
        expected_expires = config.timestamp_config.created_at + 300
        expect(config.timestamp_config.expires_at).to be_within(1).of(expected_expires)
      end

      it 'marks config as configured' do
        expect(config.configured?).to be true
      end

      it 'returns self for method chaining' do
        new_config = described_class.new
        expect(new_config.timestamp).to eq(new_config)
      end
    end

    context 'with custom expires_in' do
      before do
        config.timestamp(expires_in: 600)
      end

      it 'uses the custom expiration time' do
        expected_expires = config.timestamp_config.created_at + 600
        expect(config.timestamp_config.expires_at).to eq(expected_expires)
      end
    end

    context 'with explicit expires_at' do
      let(:custom_time) { Time.utc(2026, 1, 15, 12, 0, 0) }

      before do
        config.timestamp(expires_at: custom_time)
      end

      it 'uses the explicit expiration time' do
        expect(config.timestamp_config.expires_at).to eq(custom_time)
      end
    end

    context 'with custom created_at' do
      let(:custom_time) { Time.utc(2026, 1, 15, 10, 0, 0) }

      before do
        config.timestamp(created_at: custom_time)
      end

      it 'uses the provided created_at time' do
        expect(config.timestamp_config.created_at).to eq(custom_time)
      end
    end
  end

  describe '#signature' do
    subject(:config) { described_class.new }

    context 'with OpenSSL objects' do
      before do
        config.signature(certificate: certificate, private_key: private_key)
      end

      it 'creates a Signature config' do
        expect(config.signature_config).to be_a(WSDL::Security::Signature)
      end

      it 'stores the certificate' do
        expect(config.signature_config.certificate).to eq(certificate)
      end

      it 'stores the private key' do
        expect(config.signature_config.private_key).to eq(private_key)
      end

      it 'defaults to sha256 digest algorithm' do
        expect(config.signature_config.digest_algorithm).to eq(:sha256)
      end

      it 'marks config as configured' do
        expect(config.configured?).to be true
      end

      it 'returns self for method chaining' do
        new_config = described_class.new
        expect(new_config.signature(certificate: certificate, private_key: private_key)).to eq(new_config)
      end
    end

    context 'with PEM strings' do
      let(:cert_pem) { certificate.to_pem }
      let(:key_pem) { private_key.to_pem }

      before do
        config.signature(certificate: cert_pem, private_key: key_pem)
      end

      it 'converts certificate PEM to Certificate object' do
        expect(config.signature_config.certificate).to be_a(OpenSSL::X509::Certificate)
      end

      it 'converts key PEM to key object' do
        expect(config.signature_config.private_key).to be_a(OpenSSL::PKey::RSA)
      end
    end

    context 'with encrypted private key' do
      let(:encrypted_key_pem) { private_key.to_pem(OpenSSL::Cipher.new('AES-256-CBC'), 'password') }

      it 'decrypts the key with password' do
        config.signature(
          certificate: certificate,
          private_key: encrypted_key_pem,
          key_password: 'password'
        )

        expect(config.signature_config.private_key).to be_a(OpenSSL::PKey::RSA)
      end
    end

    context 'with custom digest algorithm' do
      before do
        config.signature(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha512
        )
      end

      it 'uses the specified digest algorithm' do
        expect(config.signature_config.digest_algorithm).to eq(:sha512)
      end
    end

    context 'with sign_body option' do
      it 'defaults sign_body to true' do
        config.signature(certificate: certificate, private_key: private_key)
        expect(config.sign_body?).to be true
      end

      it 'can disable body signing' do
        config.signature(certificate: certificate, private_key: private_key, sign_body: false)
        expect(config.sign_body?).to be false
      end
    end

    context 'with sign_timestamp option' do
      it 'defaults sign_timestamp to true' do
        config.signature(certificate: certificate, private_key: private_key)
        config.timestamp
        expect(config.sign_timestamp?).to be true
      end

      it 'can disable timestamp signing' do
        config.signature(certificate: certificate, private_key: private_key, sign_timestamp: false)
        config.timestamp
        expect(config.sign_timestamp?).to be false
      end

      it 'returns false when no timestamp is configured' do
        config.signature(certificate: certificate, private_key: private_key)
        expect(config.sign_timestamp?).to be false
      end
    end

    context 'with sign_addressing option' do
      it 'defaults sign_addressing to false' do
        config.signature(certificate: certificate, private_key: private_key)
        expect(config.sign_addressing?).to be false
      end

      it 'can enable WS-Addressing signing' do
        config.signature(certificate: certificate, private_key: private_key, sign_addressing: true)
        expect(config.sign_addressing?).to be true
      end
    end

    context 'with explicit_namespace_prefixes option' do
      it 'defaults explicit_namespace_prefixes to false' do
        config.signature(certificate: certificate, private_key: private_key)
        expect(config.explicit_namespace_prefixes?).to be false
      end

      it 'can enable explicit namespace prefixes' do
        config.signature(certificate: certificate, private_key: private_key, explicit_namespace_prefixes: true)
        expect(config.explicit_namespace_prefixes?).to be true
      end

      it 'passes the option to the Signature instance' do
        config.signature(certificate: certificate, private_key: private_key, explicit_namespace_prefixes: true)
        expect(config.signature_config.explicit_namespace_prefixes?).to be true
      end
    end

    context 'with key_reference option' do
      it 'defaults to binary_security_token' do
        config.signature(certificate: certificate, private_key: private_key)
        expect(config.key_reference).to eq(:binary_security_token)
      end

      it 'can use issuer_serial reference' do
        config.signature(certificate: certificate, private_key: private_key, key_reference: :issuer_serial)
        expect(config.key_reference).to eq(:issuer_serial)
        expect(config.signature_config.key_reference).to eq(:issuer_serial)
      end

      it 'can use subject_key_identifier reference with valid certificate' do
        config.signature(
          certificate: certificate_with_ski,
          private_key: private_key,
          key_reference: :subject_key_identifier
        )
        expect(config.key_reference).to eq(:subject_key_identifier)
      end

      it 'raises error for subject_key_identifier without SKI extension' do
        expect {
          config.signature(
            certificate: certificate,
            private_key: private_key,
            key_reference: :subject_key_identifier
          )
        }.to raise_error(ArgumentError, /Subject Key Identifier extension/)
      end

      it 'raises error for invalid key_reference value' do
        expect {
          config.signature(
            certificate: certificate,
            private_key: private_key,
            key_reference: :invalid
          )
        }.to raise_error(ArgumentError, /Invalid key_reference/)
      end
    end

    context 'with invalid certificate type' do
      it 'raises ArgumentError' do
        expect {
          config.signature(certificate: 12_345, private_key: private_key)
        }.to raise_error(ArgumentError, /Invalid certificate type/)
      end
    end

    context 'with invalid private key type' do
      it 'raises ArgumentError' do
        expect {
          config.signature(certificate: certificate, private_key: 12_345)
        }.to raise_error(ArgumentError, /Invalid private_key type/)
      end
    end
  end

  describe '#verify_response' do
    subject(:config) { described_class.new }

    it 'defaults to false' do
      expect(config.verify_response).to be false
      expect(config.verify_response?).to be false
    end

    it 'can be enabled' do
      config.verify_response = true
      expect(config.verify_response).to be true
      expect(config.verify_response?).to be true
    end

    it 'can be disabled after enabling' do
      config.verify_response = true
      config.verify_response = false
      expect(config.verify_response?).to be false
    end
  end

  describe '#configured?' do
    subject(:config) { described_class.new }

    it 'returns false when nothing is configured' do
      expect(config.configured?).to be false
    end

    it 'returns true when username_token is configured' do
      config.username_token('user', 'pass')
      expect(config.configured?).to be true
    end

    it 'returns true when timestamp is configured' do
      config.timestamp
      expect(config.configured?).to be true
    end

    it 'returns true when signature is configured' do
      config.signature(certificate: certificate, private_key: private_key)
      expect(config.configured?).to be true
    end
  end

  describe '#username_token?' do
    subject(:config) { described_class.new }

    it 'returns false when not configured' do
      expect(config.username_token?).to be false
    end

    it 'returns true when configured' do
      config.username_token('user', 'pass')
      expect(config.username_token?).to be true
    end
  end

  describe '#timestamp?' do
    subject(:config) { described_class.new }

    it 'returns false when not configured' do
      expect(config.timestamp?).to be false
    end

    it 'returns true when configured' do
      config.timestamp
      expect(config.timestamp?).to be true
    end
  end

  describe '#signature?' do
    subject(:config) { described_class.new }

    it 'returns false when not configured' do
      expect(config.signature?).to be false
    end

    it 'returns true when configured' do
      config.signature(certificate: certificate, private_key: private_key)
      expect(config.signature?).to be true
    end
  end

  describe '#sign_addressing?' do
    subject(:config) { described_class.new }

    it 'returns false when signature is not configured' do
      expect(config.sign_addressing?).to be false
    end

    it 'returns false when sign_addressing is not enabled' do
      config.signature(certificate: certificate, private_key: private_key)
      expect(config.sign_addressing?).to be false
    end

    it 'returns true when sign_addressing is enabled' do
      config.signature(certificate: certificate, private_key: private_key, sign_addressing: true)
      expect(config.sign_addressing?).to be true
    end
  end

  describe '#explicit_namespace_prefixes?' do
    subject(:config) { described_class.new }

    it 'returns false when signature is not configured' do
      expect(config.explicit_namespace_prefixes?).to be false
    end

    it 'returns false when explicit_namespace_prefixes is not enabled' do
      config.signature(certificate: certificate, private_key: private_key)
      expect(config.explicit_namespace_prefixes?).to be false
    end

    it 'returns true when explicit_namespace_prefixes is enabled' do
      config.signature(certificate: certificate, private_key: private_key, explicit_namespace_prefixes: true)
      expect(config.explicit_namespace_prefixes?).to be true
    end
  end

  describe '#clear' do
    subject(:config) { described_class.new }

    before do
      config.username_token('user', 'pass')
      config.timestamp
      config.signature(
        certificate: certificate,
        private_key: private_key,
        sign_addressing: true,
        explicit_namespace_prefixes: true,
        key_reference: :issuer_serial
      )
      config.verify_response = true
      config.clear
    end

    it 'clears username_token_config' do
      expect(config.username_token_config).to be_nil
    end

    it 'clears timestamp_config' do
      expect(config.timestamp_config).to be_nil
    end

    it 'clears signature_config' do
      expect(config.signature_config).to be_nil
    end

    it 'resets sign_addressing' do
      expect(config.sign_addressing?).to be false
    end

    it 'resets explicit_namespace_prefixes' do
      expect(config.explicit_namespace_prefixes?).to be false
    end

    it 'resets key_reference to default' do
      expect(config.key_reference).to eq(:binary_security_token)
    end

    it 'resets verify_response' do
      expect(config.verify_response?).to be false
    end

    it 'marks config as not configured' do
      expect(config.configured?).to be false
    end

    it 'returns self for method chaining' do
      new_config = described_class.new
      new_config.username_token('u', 'p')
      expect(new_config.clear).to eq(new_config)
    end
  end

  describe '#dup' do
    subject(:config) { described_class.new }

    context 'with username_token configured' do
      before do
        config.username_token('user', 'secret', digest: true)
      end

      it 'creates a new Config instance' do
        copy = config.dup
        expect(copy).to be_a(described_class)
        expect(copy).not_to equal(config)
      end

      it 'copies username_token configuration' do
        copy = config.dup
        expect(copy.username_token?).to be true
        expect(copy.username_token_config.username).to eq('user')
        expect(copy.username_token_config.password).to eq('secret')
        expect(copy.username_token_config.digest?).to be true
      end
    end

    context 'with timestamp configured' do
      before do
        config.timestamp(expires_in: 600)
      end

      it 'copies timestamp configuration' do
        copy = config.dup
        expect(copy.timestamp?).to be true
      end
    end

    context 'with signature configured including new options' do
      before do
        config.signature(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha512,
          sign_body: false,
          sign_timestamp: false,
          sign_addressing: true,
          explicit_namespace_prefixes: true,
          key_reference: :issuer_serial
        )
        config.verify_response = true
      end

      it 'copies signature configuration' do
        copy = config.dup
        expect(copy.signature?).to be true
        expect(copy.signature_config.certificate).to eq(certificate)
        expect(copy.signature_config.private_key).to eq(private_key)
        expect(copy.signature_config.digest_algorithm).to eq(:sha512)
        expect(copy.sign_body?).to be false
      end

      it 'copies sign_addressing' do
        copy = config.dup
        expect(copy.sign_addressing?).to be true
      end

      it 'copies explicit_namespace_prefixes' do
        copy = config.dup
        expect(copy.explicit_namespace_prefixes?).to be true
      end

      it 'copies key_reference' do
        copy = config.dup
        expect(copy.key_reference).to eq(:issuer_serial)
      end

      it 'copies verify_response' do
        copy = config.dup
        expect(copy.verify_response?).to be true
      end
    end

    context 'with empty config' do
      it 'creates an empty copy' do
        copy = config.dup
        expect(copy.configured?).to be false
      end
    end
  end

  describe 'method chaining' do
    subject(:config) { described_class.new }

    it 'supports chaining multiple configuration methods' do
      result = config
        .username_token('user', 'pass')
        .timestamp(expires_in: 300)
        .signature(
          certificate: certificate,
          private_key: private_key,
          sign_addressing: true,
          explicit_namespace_prefixes: true
        )

      expect(result).to eq(config)
      expect(config.username_token?).to be true
      expect(config.timestamp?).to be true
      expect(config.signature?).to be true
      expect(config.sign_addressing?).to be true
      expect(config.explicit_namespace_prefixes?).to be true
    end
  end
end
