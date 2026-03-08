# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Signature do
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

    context 'when certificate.subject raises' do
      it 'falls back to unknown for certificate subject' do
        bad_cert = instance_double(OpenSSL::X509::Certificate)
        allow(bad_cert).to receive(:subject).and_raise(StandardError, 'broken')

        sig = described_class.new(
          certificate: bad_cert,
          private_key: private_key,
          digest_algorithm: :sha256
        )

        expect(sig.inspect).to include('certificate="unknown"')
        expect(sig.inspect).to include('private_key=[REDACTED]')
      end
    end
  end

  describe '#sign_element with inclusive_namespaces' do
    it 'includes InclusiveNamespaces element in the signed reference' do
      sig = described_class.new(
        certificate: certificate,
        private_key: private_key,
        digest_algorithm: :sha256
      )

      envelope = Nokogiri::XML(<<~XML)
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header>
            <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"/>
          </soap:Header>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-123">
            <Data>Test</Data>
          </soap:Body>
        </soap:Envelope>
      XML

      body = envelope.at_xpath('//soap:Body',
                               'soap' => 'http://schemas.xmlsoap.org/soap/envelope/')
      security = envelope.at_xpath('//wsse:Security',
                                   'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd')

      sig.sign_element(body, inclusive_namespaces: %w[soap])
      sig.apply(envelope, security)

      ns = {
        'ds' => 'http://www.w3.org/2000/09/xmldsig#',
        'ec' => 'http://www.w3.org/2001/10/xml-exc-c14n#'
      }

      inclusive = envelope.at_xpath('//ds:Reference/ds:Transforms/ds:Transform/ec:InclusiveNamespaces', ns)
      expect(inclusive).not_to be_nil
      expect(inclusive['PrefixList']).to eq('soap')
    end
  end

  describe '#explicit_namespace_prefixes?' do
    it 'returns false by default' do
      sig = described_class.new(
        certificate: certificate,
        private_key: private_key
      )

      expect(sig.explicit_namespace_prefixes?).to be false
    end

    it 'returns true when enabled' do
      sig = described_class.new(
        certificate: certificate,
        private_key: private_key,
        explicit_namespace_prefixes: true
      )

      expect(sig.explicit_namespace_prefixes?).to be true
    end
  end
end
