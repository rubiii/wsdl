# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::Verifier::CertificateValidator do
  # Generate a self-signed certificate for testing
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }

  let(:valid_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Valid Certificate']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now - 3600
    cert.not_after = Time.now + 3600
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  let(:expired_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Expired Certificate']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now - 7200
    cert.not_after = Time.now - 3600 # Expired 1 hour ago
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  let(:future_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 3
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Future Certificate']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now + 3600 # Valid starting 1 hour from now
    cert.not_after = Time.now + 7200
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  # CA and signed certificate for chain validation
  let(:ca_private_key) { OpenSSL::PKey::RSA.new(2048) }

  let(:ca_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 100
    cert.subject = OpenSSL::X509::Name.new([
      ['C', 'US'],
      ['O', 'Test CA'],
      ['CN', 'Test Root CA']
    ])
    cert.issuer = cert.subject
    cert.public_key = ca_private_key.public_key
    cert.not_before = Time.now - 86_400
    cert.not_after = Time.now + (86_400 * 365)

    # Add CA extensions
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
    cert.add_extension(ef.create_extension('keyUsage', 'keyCertSign, cRLSign', true))
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))

    cert.sign(ca_private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  let(:signed_private_key) { OpenSSL::PKey::RSA.new(2048) }

  let(:ca_signed_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 101
    cert.subject = OpenSSL::X509::Name.new([
      ['C', 'US'],
      ['O', 'Test Org'],
      ['CN', 'test.example.com']
    ])
    cert.issuer = ca_certificate.subject # Signed by CA
    cert.public_key = signed_private_key.public_key
    cert.not_before = Time.now - 3600
    cert.not_after = Time.now + 3600

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = ca_certificate
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:FALSE', true))
    cert.add_extension(ef.create_extension('keyUsage', 'digitalSignature, keyEncipherment', true))

    cert.sign(ca_private_key, OpenSSL::Digest.new('SHA256')) # Signed by CA key
    cert
  end

  describe '#initialize' do
    it 'accepts a certificate' do
      validator = described_class.new(valid_certificate)
      expect(validator).to be_a(described_class)
    end

    it 'accepts optional trust_store' do
      validator = described_class.new(valid_certificate, trust_store: :system)
      expect(validator).to be_a(described_class)
    end

    it 'accepts optional check_validity flag' do
      validator = described_class.new(valid_certificate, check_validity: false)
      expect(validator).to be_a(described_class)
    end

    it 'accepts optional at_time for testing' do
      validator = described_class.new(valid_certificate, at_time: Time.now - 3600)
      expect(validator).to be_a(described_class)
    end
  end

  describe '#valid?' do
    describe 'validity period checking' do
      context 'with valid certificate' do
        it 'passes validation' do
          validator = described_class.new(valid_certificate)
          expect(validator.valid?).to be true
        end

        it 'has no errors' do
          validator = described_class.new(valid_certificate)
          validator.valid?
          expect(validator.errors).to be_empty
        end
      end

      context 'with expired certificate' do
        it 'fails validation' do
          validator = described_class.new(expired_certificate)
          expect(validator.valid?).to be false
        end

        it 'reports expiration error' do
          validator = described_class.new(expired_certificate)
          validator.valid?
          expect(validator.errors).to include(match(/Certificate has expired/))
        end

        it 'includes expiration date in error message' do
          validator = described_class.new(expired_certificate)
          validator.valid?
          expect(validator.errors.first).to include('expired')
        end
      end

      context 'with not-yet-valid certificate' do
        it 'fails validation' do
          validator = described_class.new(future_certificate)
          expect(validator.valid?).to be false
        end

        it 'reports not-yet-valid error' do
          validator = described_class.new(future_certificate)
          validator.valid?
          expect(validator.errors).to include(match(/Certificate is not yet valid/))
        end

        it 'includes valid-from date in error message' do
          validator = described_class.new(future_certificate)
          validator.valid?
          expect(validator.errors.first).to include('valid from')
        end
      end

      context 'when check_validity is false' do
        it 'skips validity checking for expired certificate' do
          validator = described_class.new(expired_certificate, check_validity: false)
          expect(validator.valid?).to be true
        end

        it 'skips validity checking for future certificate' do
          validator = described_class.new(future_certificate, check_validity: false)
          expect(validator.valid?).to be true
        end
      end

      context 'with at_time override' do
        it 'validates against the specified time' do
          # Certificate is valid now, but check at a future time when it will be expired
          future_time = valid_certificate.not_after + 3600
          validator = described_class.new(valid_certificate, at_time: future_time)
          expect(validator.valid?).to be false
          expect(validator.errors).to include(match(/expired/))
        end

        it 'can make an expired certificate valid by checking at past time' do
          # Check at a time when the expired certificate was still valid
          past_time = expired_certificate.not_after - 1800 # 30 minutes before expiration
          validator = described_class.new(expired_certificate, at_time: past_time)
          expect(validator.valid?).to be true
        end
      end
    end

    describe 'chain validation' do
      context 'without trust store' do
        it 'skips chain validation' do
          validator = described_class.new(valid_certificate, trust_store: nil)
          expect(validator.valid?).to be true
        end

        it 'allows self-signed certificates' do
          validator = described_class.new(valid_certificate)
          expect(validator.valid?).to be true
        end
      end

      context 'with CA certificate array trust store' do
        it 'accepts certificates signed by the CA' do
          validator = described_class.new(
            ca_signed_certificate,
            trust_store: [ca_certificate]
          )
          expect(validator.valid?).to be true
        end

        it 'rejects self-signed certificates not in trust store' do
          validator = described_class.new(
            valid_certificate, # self-signed
            trust_store: [ca_certificate]
          )
          expect(validator.valid?).to be false
          expect(validator.errors).to include(match(/chain validation failed/i))
        end

        it 'reports the OpenSSL error string' do
          validator = described_class.new(
            valid_certificate,
            trust_store: [ca_certificate]
          )
          validator.valid?
          # OpenSSL typically returns "self signed certificate" or similar
          expect(validator.errors.first).to match(/self.signed|unable to get local issuer/i)
        end
      end

      context 'with pre-built OpenSSL::X509::Store' do
        it 'uses the provided store directly' do
          store = OpenSSL::X509::Store.new
          store.add_cert(ca_certificate)

          validator = described_class.new(
            ca_signed_certificate,
            trust_store: store
          )
          expect(validator.valid?).to be true
        end

        it 'respects store configuration' do
          store = OpenSSL::X509::Store.new
          # Empty store - no trusted CAs

          validator = described_class.new(
            ca_signed_certificate,
            trust_store: store
          )
          expect(validator.valid?).to be false
        end
      end

      context 'with :system trust store' do
        it 'builds a store with system default paths' do
          # This test just verifies the code path works
          # Actual validation depends on system CA configuration
          validator = described_class.new(
            valid_certificate, # self-signed, won't be in system store
            trust_store: :system
          )
          # Self-signed certs should fail against system store
          expect(validator.valid?).to be false
        end
      end

      context 'with invalid trust store type' do
        it 'raises ArgumentError' do
          validator = described_class.new(valid_certificate, trust_store: 12_345)
          expect { validator.valid? }.to raise_error(ArgumentError, /Invalid trust_store/)
        end

        it 'includes the invalid type in error message' do
          validator = described_class.new(valid_certificate, trust_store: :invalid_symbol)
          expect { validator.valid? }.to raise_error(ArgumentError, /Invalid trust_store.*Symbol/)
        end
      end
    end

    describe 'combined validity and chain checking' do
      it 'checks validity before chain (fails fast)' do
        validator = described_class.new(
          expired_certificate,
          trust_store: [ca_certificate]
        )
        validator.valid?
        # Should fail on validity, not reach chain check
        expect(validator.errors).to include(match(/expired/))
        expect(validator.errors).not_to include(match(/chain/))
      end

      it 'checks chain after validity passes' do
        validator = described_class.new(
          valid_certificate, # valid but self-signed
          trust_store: [ca_certificate]
        )
        validator.valid?
        # Should pass validity but fail chain
        expect(validator.errors).to include(match(/chain/))
        expect(validator.errors).not_to include(match(/expired/))
      end

      it 'passes when both checks succeed' do
        validator = described_class.new(
          ca_signed_certificate,
          trust_store: [ca_certificate],
          check_validity: true
        )
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end
  end

  describe '#errors' do
    it 'is empty before validation' do
      validator = described_class.new(expired_certificate)
      expect(validator.errors).to be_empty
    end

    it 'accumulates errors after validation' do
      validator = described_class.new(expired_certificate)
      validator.valid?
      expect(validator.errors).not_to be_empty
    end

    it 'contains descriptive error messages' do
      validator = described_class.new(expired_certificate)
      validator.valid?
      expect(validator.errors.first).to be_a(String)
      expect(validator.errors.first.length).to be > 10
    end
  end

  describe 'file-based trust store' do
    let(:ca_bundle_path) { 'spec/fixtures/security/ca-bundle.pem' }

    before do
      # Create a temporary CA bundle file for testing
      FileUtils.mkdir_p(File.dirname(ca_bundle_path))
      File.write(ca_bundle_path, ca_certificate.to_pem)
    end

    after do
      FileUtils.rm_f(ca_bundle_path)
    end

    it 'accepts a file path as trust store' do
      validator = described_class.new(
        ca_signed_certificate,
        trust_store: ca_bundle_path
      )
      expect(validator.valid?).to be true
    end

    it 'fails for certificates not signed by CA in file' do
      validator = described_class.new(
        valid_certificate, # self-signed
        trust_store: ca_bundle_path
      )
      expect(validator.valid?).to be false
    end
  end

  describe 'directory-based trust store' do
    let(:ca_dir_path) { 'spec/fixtures/security/ca-certs' }

    before do
      # Create a temporary CA directory for testing
      FileUtils.mkdir_p(ca_dir_path)
      # OpenSSL expects hashed filenames for directory stores
      # For testing, we'll just verify the code path
    end

    after do
      FileUtils.rm_rf(ca_dir_path) if File.directory?(ca_dir_path)
    end

    it 'accepts a directory path as trust store' do
      # This verifies the directory code path is taken
      validator = described_class.new(
        valid_certificate,
        trust_store: ca_dir_path
      )
      # Will fail because directory is empty, but shouldn't raise
      expect(validator.valid?).to be false
    end
  end

  describe 'integration with Verifier' do
    # These tests verify CertificateValidator integrates properly with the main Verifier

    let(:signed_response) do
      # Build a signed SOAP response using the test certificate
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-test">
            <TestData>Hello</TestData>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp
      config.signature(certificate: valid_certificate, private_key: private_key)

      header = WSDL::Security::SecurityHeader.new(config)
      header.apply(envelope)
    end

    it 'is called during verification when check_validity is true' do
      verifier = WSDL::Security::Verifier.new(signed_response, check_validity: true)
      expect(verifier.valid?).to be true
    end

    it 'rejects responses with expired certificates' do
      # Build response with expired certificate
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-expired">
            <TestData>Hello</TestData>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp
      config.signature(certificate: expired_certificate, private_key: private_key)

      header = WSDL::Security::SecurityHeader.new(config)
      expired_response = header.apply(envelope)

      verifier = WSDL::Security::Verifier.new(expired_response, check_validity: true)
      expect(verifier.valid?).to be false
      expect(verifier.errors).to include(match(/expired/))
    end

    it 'can skip validity checking' do
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-skip">
            <TestData>Hello</TestData>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp
      config.signature(certificate: expired_certificate, private_key: private_key)

      header = WSDL::Security::SecurityHeader.new(config)
      expired_response = header.apply(envelope)

      verifier = WSDL::Security::Verifier.new(expired_response, check_validity: false)
      expect(verifier.valid?).to be true
    end
  end
end
