# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::Signature do
  # Generate a self-signed certificate and key for testing
  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Test Signature Certificate']])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  describe '#inspect' do
    subject(:signature) do
      described_class.new(
        certificate: certificate,
        private_key: private_key,
        digest_algorithm: :sha256
      )
    end

    it 'includes the class name' do
      expect(signature.inspect).to include('WSDL::Security::Signature')
    end

    it 'includes the algorithm' do
      expect(signature.inspect).to include('algorithm=:sha256')
    end

    it 'includes the key_reference' do
      expect(signature.inspect).to include('key_reference=:binary_security_token')
    end

    it 'redacts the private key' do
      expect(signature.inspect).to include('private_key=[REDACTED]')
    end

    it 'includes the certificate subject' do
      # OpenSSL formats the subject with a leading slash
      expect(signature.inspect).to include('certificate="/CN=Test Signature Certificate"')
    end

    it 'includes the references count' do
      expect(signature.inspect).to include('references=0')
    end

    it 'never exposes private key material in any form' do
      output = signature.inspect

      # Ensure no PEM markers
      expect(output).not_to include('BEGIN')
      expect(output).not_to include('PRIVATE KEY')
      expect(output).not_to include('RSA')

      # Ensure no raw key data
      expect(output).not_to include(private_key.to_pem)
      expect(output).not_to include(private_key.to_der.inspect)
    end

    context 'with different algorithms' do
      it 'shows sha1 algorithm' do
        sig = described_class.new(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha1
        )
        expect(sig.inspect).to include('algorithm=:sha1')
        expect(sig.inspect).to include('private_key=[REDACTED]')
      end

      it 'shows sha512 algorithm' do
        sig = described_class.new(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha512
        )
        expect(sig.inspect).to include('algorithm=:sha512')
        expect(sig.inspect).to include('private_key=[REDACTED]')
      end
    end

    context 'with different key reference methods' do
      it 'shows issuer_serial reference' do
        sig = described_class.new(
          certificate: certificate,
          private_key: private_key,
          key_reference: :issuer_serial
        )
        expect(sig.inspect).to include('key_reference=:issuer_serial')
        expect(sig.inspect).to include('private_key=[REDACTED]')
      end
    end

    context 'security scenarios' do
      it 'is safe when used in string interpolation' do
        output = "Signature: #{signature.inspect}"
        expect(output).not_to include('BEGIN')
        expect(output).not_to include('PRIVATE KEY')
        expect(output).to include('[REDACTED]')
      end

      it 'is safe when used in exception messages' do
        raise StandardError, "Signature error: #{signature.inspect}"
      rescue StandardError => e
        expect(e.message).not_to include('BEGIN')
        expect(e.message).not_to include('PRIVATE KEY')
        expect(e.message).to include('[REDACTED]')
      end

      it 'is safe when signature is in an array' do
        array = [signature, 'other']
        output = array.inspect
        expect(output).not_to include('BEGIN')
        expect(output).not_to include('PRIVATE KEY')
        expect(output).to include('[REDACTED]')
      end

      it 'is safe when signature is in a hash' do
        hash = { signature: signature, name: 'test' }
        output = hash.inspect
        expect(output).not_to include('BEGIN')
        expect(output).not_to include('PRIVATE KEY')
        expect(output).to include('[REDACTED]')
      end

      it 'is safe when p() is called' do
        # p() internally calls inspect
        output = signature.inspect
        expect(output).not_to include('BEGIN')
        expect(output).not_to include('PRIVATE KEY')
      end
    end
  end
end
