# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_context'

describe WSDL::Security::Verifier::StructureValidator, :verifier_helpers do
  let(:document) { parse_xml(xml) }
  let(:validator) { described_class.new(document) }

  describe '#valid?' do
    context 'with a valid signed document' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'adds error about missing signature' do
        validator.valid?
        expect(validator.errors).to include('No signature found in document')
      end
    end
  end

  describe '#signature_present?' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(validator.signature_present?).to be true
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }

      it 'returns false' do
        expect(validator.signature_present?).to be false
      end
    end
  end

  describe '#signature_node' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns the ds:Signature element' do
        expect(validator.signature_node).to be_a(Nokogiri::XML::Element)
        expect(validator.signature_node.name).to eq('Signature')
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }

      it 'returns nil' do
        expect(validator.signature_node).to be_nil
      end
    end
  end

  describe '#security_node' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns the wsse:Security element' do
        expect(validator.security_node).to be_a(Nokogiri::XML::Element)
        expect(validator.security_node.name).to eq('Security')
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }

      it 'returns nil' do
        expect(validator.security_node).to be_nil
      end
    end
  end

  describe 'duplicate ID detection' do
    let(:duplicate_id_fixture) { File.read('spec/fixtures/security/xsw_duplicate_id.xml') }

    context 'with duplicate wsu:Id attributes' do
      let(:xml) { duplicate_id_fixture }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports the duplicate IDs' do
        validator.valid?
        expect(validator.errors).to include(match(/Duplicate element IDs detected.*Body-duplicate/))
      end

      it 'includes "signature wrapping attack" in the error message' do
        validator.valid?
        expect(validator.errors.join).to include('signature wrapping attack')
      end
    end

    context 'with unique IDs' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no duplicate ID errors' do
        validator.valid?
        expect(validator.errors).not_to include(match(/Duplicate element IDs/))
      end
    end

    context 'with duplicate IDs across different attribute types (wsu:Id vs bare Id)' do
      let(:xml) do
        cert_data = Base64.strict_encode64(certificate.to_der)
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security soap:mustUnderstand="1">
                <wsse:BinarySecurityToken wsu:Id="Token-1"
                  ValueType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3"
                  EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">#{cert_data}</wsse:BinarySecurityToken>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#Body-crossattr">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
                  <ds:SignatureValue>fakesig==</ds:SignatureValue>
                </ds:Signature>
                <MaliciousElement Id="Body-crossattr"><Evil/></MaliciousElement>
              </wsse:Security>
            </soap:Header>
            <soap:Body wsu:Id="Body-crossattr">
              <Data>Test</Data>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'detects the cross-attribute duplicate' do
        validator.valid?
        expect(validator.errors).to include(match(/Duplicate element IDs.*Body-crossattr/))
      end
    end

    context 'with multiple elements having different IDs' do
      let(:xml) { build_minimal_signed_document(body_id: 'Body-unique', timestamp_id: 'Timestamp-unique') }

      it 'returns true' do
        # NOTE: This document has fake signatures so won't pass full verification,
        # but structural validation should pass
        expect(validator.valid?).to be true
      end
    end
  end

  describe 'signature location validation' do
    context 'with signature inside wsse:Security header' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no signature location errors' do
        validator.valid?
        expect(validator.errors).not_to include(match(/Signature element must be within/))
      end
    end

    context 'with signature outside wsse:Security header' do
      let(:xml) { File.read('spec/fixtures/security/xsw_signature_outside_security.xml') }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports signature location error' do
        validator.valid?
        expect(validator.errors).to include(match(/Signature element must be within wsse:Security header/))
      end

      it 'includes "signature wrapping attack" in the error message' do
        validator.valid?
        expect(validator.errors.join).to include('signature wrapping attack')
      end
    end

    context 'with signature directly under soap:Header' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
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
            </soap:Header>
            <soap:Body>
              <Data>Test</Data>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports signature location error' do
        validator.valid?
        expect(validator.errors).to include(match(/Signature element must be within wsse:Security header/))
      end
    end

    context 'with signature in soap:Body' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header/>
            <soap:Body>
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
              <Data>Test</Data>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end
    end
  end

  describe 'error aggregation' do
    let(:xml) { unsigned_soap_response }

    it 'starts with empty errors' do
      expect(validator.errors).to be_empty
    end

    it 'accumulates errors after validation' do
      validator.valid?
      expect(validator.errors).not_to be_empty
    end
  end
end
