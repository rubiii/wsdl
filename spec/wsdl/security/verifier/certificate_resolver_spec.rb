# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_context'

describe WSDL::Security::Verifier::CertificateResolver, :verifier_helpers do
  let(:document) { parse_xml(xml) }
  let(:security_node) { document.at_xpath('//wsse:Security', ns) }
  let(:resolver) { described_class.new(document, security_node, provided: provided_cert) }
  let(:provided_cert) { nil }

  describe '#resolve' do
    context 'with a valid BinarySecurityToken' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(resolver.resolve).to be true
      end

      it 'extracts the certificate' do
        resolver.resolve
        expect(resolver.certificate).to be_a(OpenSSL::X509::Certificate)
      end

      it 'has no errors' do
        resolver.resolve
        expect(resolver.errors).to be_empty
      end
    end

    context 'with a provided certificate object' do
      let(:xml) { unsigned_soap_response }
      let(:provided_cert) { certificate }

      it 'returns true' do
        expect(resolver.resolve).to be true
      end

      it 'uses the provided certificate' do
        resolver.resolve
        expect(resolver.certificate).to eq(certificate)
      end

      it 'has no errors' do
        resolver.resolve
        expect(resolver.errors).to be_empty
      end
    end

    context 'with a provided PEM string' do
      let(:xml) { unsigned_soap_response }
      let(:provided_cert) { certificate.to_pem }

      it 'returns true' do
        expect(resolver.resolve).to be true
      end

      it 'parses the PEM string into a certificate' do
        resolver.resolve
        expect(resolver.certificate).to be_a(OpenSSL::X509::Certificate)
        expect(resolver.certificate.subject.to_s).to eq(certificate.subject.to_s)
      end
    end

    context 'with a provided DER-encoded certificate' do
      let(:xml) { unsigned_soap_response }
      let(:provided_cert) { certificate.to_der }

      it 'returns true' do
        expect(resolver.resolve).to be true
      end

      it 'parses the DER data into a certificate' do
        resolver.resolve
        expect(resolver.certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'without BinarySecurityToken and no provided certificate' do
      let(:xml) { unsigned_soap_response }

      it 'returns false' do
        expect(resolver.resolve).to be false
      end

      it 'adds error about missing certificate' do
        resolver.resolve
        expect(resolver.errors).to include('No certificate found for verification')
      end

      it 'does not set certificate' do
        resolver.resolve
        expect(resolver.certificate).to be_nil
      end
    end

    context 'with invalid provided certificate type' do
      let(:xml) { unsigned_soap_response }
      let(:provided_cert) { 12_345 }

      it 'returns false' do
        expect(resolver.resolve).to be false
      end

      it 'adds error about invalid type' do
        resolver.resolve
        expect(resolver.errors).to include(match(/Invalid certificate type/))
      end
    end

    context 'with invalid PEM data' do
      let(:xml) { unsigned_soap_response }
      let(:provided_cert) { 'not a valid certificate' }

      it 'returns false' do
        expect(resolver.resolve).to be false
      end

      it 'adds error about parsing failure' do
        resolver.resolve
        expect(resolver.errors).to include(match(/Failed to parse certificate/))
      end
    end

    context 'with empty BinarySecurityToken' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <wsse:BinarySecurityToken wsu:Id="Token-123"
                  ValueType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3"
                  EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary"></wsse:BinarySecurityToken>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#Body-123">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
                  <ds:SignatureValue>fakesig==</ds:SignatureValue>
                </ds:Signature>
              </wsse:Security>
            </soap:Header>
            <soap:Body wsu:Id="Body-123">
              <Data>Test</Data>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns false' do
        expect(resolver.resolve).to be false
      end

      it 'adds error about parsing failure' do
        resolver.resolve
        expect(resolver.errors).to include(match(/Failed to parse certificate/))
      end
    end

    context 'with nil security_node' do
      let(:xml) { unsigned_soap_response }
      let(:resolver) { described_class.new(document, nil) }

      it 'returns false' do
        expect(resolver.resolve).to be false
      end

      it 'adds error about missing certificate' do
        resolver.resolve
        expect(resolver.errors).to include('No certificate found for verification')
      end
    end
  end

  describe '#valid?' do
    context 'with a valid BinarySecurityToken' do
      let(:xml) { signed_soap_response }

      it 'returns true (alias for resolve)' do
        expect(resolver.valid?).to be true
      end
    end

    context 'without certificate' do
      let(:xml) { unsigned_soap_response }

      it 'returns false (alias for resolve)' do
        expect(resolver.valid?).to be false
      end
    end
  end

  describe '#certificate' do
    context 'before resolve is called' do
      let(:xml) { signed_soap_response }

      it 'returns nil' do
        expect(resolver.certificate).to be_nil
      end
    end

    context 'after successful resolve' do
      let(:xml) { signed_soap_response }

      it 'returns the certificate' do
        resolver.resolve
        expect(resolver.certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'after failed resolve' do
      let(:xml) { unsigned_soap_response }

      it 'returns nil' do
        resolver.resolve
        expect(resolver.certificate).to be_nil
      end
    end
  end

  describe 'priority of provided vs extracted certificate' do
    let(:xml) { signed_soap_response }
    let(:provided_cert) { other_certificate }

    it 'uses the provided certificate over the extracted one' do
      resolver.resolve
      # The provided certificate should be used, not the one from the document
      expect(resolver.certificate.subject.to_s).to eq(other_certificate.subject.to_s)
      expect(resolver.certificate.subject.to_s).not_to eq(certificate.subject.to_s)
    end
  end
end
