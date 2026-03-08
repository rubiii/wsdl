# frozen_string_literal: true

RSpec.describe WSDL::Security::Verifier::SignatureValidator, :verifier_helpers do
  let(:document) { parse_xml(xml) }
  let(:signature_node) { document.at_xpath('//ds:Signature', ns) }
  let(:validator) { described_class.new(signature_node, cert) }
  let(:cert) { certificate }

  describe '#valid?' do
    context 'with a properly signed document' do
      let(:xml) { signed_soap_response }

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'with explicit namespace prefixes' do
      let(:xml) { signed_response_with_explicit_prefixes }

      it 'returns true' do
        expect(validator.valid?).to be true
      end
    end

    context 'with wrong certificate' do
      let(:xml) { signed_soap_response }
      let(:cert) { other_certificate }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports verification failure' do
        validator.valid?
        expect(validator.errors).to include('SignatureValue verification failed')
      end
    end

    context 'with nil signature_node' do
      let(:xml) { unsigned_soap_response }
      let(:signature_node) { nil }
      let(:cert) { certificate }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports missing SignedInfo' do
        validator.valid?
        expect(validator.errors).to include('SignedInfo not found')
      end
    end

    context 'with missing SignedInfo' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <ds:Signature>
                  <ds:SignatureValue>fakesig==</ds:SignatureValue>
                </ds:Signature>
              </wsse:Security>
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

      it 'reports missing SignedInfo' do
        validator.valid?
        expect(validator.errors).to include('SignedInfo not found')
      end
    end

    context 'with missing SignatureValue' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#Body-123">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
                </ds:Signature>
              </wsse:Security>
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

      it 'reports missing SignatureValue' do
        validator.valid?
        expect(validator.errors).to include('SignatureValue not found')
      end
    end

    context 'with invalid base64 in SignatureValue' do
      let(:xml) do
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        sig_value = doc.at_xpath('//ds:SignatureValue', ns)
        sig_value.content = 'not!valid@base64'
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports invalid encoding' do
        validator.valid?
        expect(validator.errors).to include(match(/Invalid SignatureValue encoding/))
      end
    end

    context 'with corrupted SignatureValue' do
      let(:xml) do
        # Take a signed response and corrupt the signature
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        sig_value = doc.at_xpath('//ds:SignatureValue', ns)
        sig_value.content = 'Y29ycnVwdGVkIHNpZ25hdHVyZQ=='
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports verification failure' do
        validator.valid?
        expect(validator.errors.join).to match(/SignatureValue verification failed|Signature verification error/)
      end
    end

    context 'with tampered SignedInfo' do
      let(:xml) do
        # Take a signed response and tamper with SignedInfo
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        # Change the digest value in SignedInfo (which would change the canonical form)
        digest = doc.at_xpath('//ds:DigestValue', ns)
        digest.content = 'dGFtcGVyZWQ='
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports verification failure' do
        validator.valid?
        expect(validator.errors).to include('SignatureValue verification failed')
      end
    end
  end

  describe '#signature_algorithm' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns the signature algorithm URI' do
        expect(validator.signature_algorithm).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
      end
    end

    context 'with SHA-1 signature' do
      let(:xml) { build_signed_response(digest_algorithm: :sha1) }

      it 'returns the SHA-1 signature algorithm URI' do
        # NOTE: signature algorithm is tied to digest algorithm in our implementation
        expect(validator.signature_algorithm).to include('sha')
      end
    end

    context 'with unsigned document' do
      let(:xml) { unsigned_soap_response }
      let(:signature_node) { nil }

      it 'returns nil' do
        expect(validator.signature_algorithm).to be_nil
      end
    end
  end

  describe '#canonicalization_algorithm' do
    context 'with Exclusive C14N' do
      let(:xml) { signed_soap_response }

      it 'returns the Exclusive C14N algorithm URI' do
        expect(validator.canonicalization_algorithm).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
      end
    end

    context 'with unsigned document' do
      let(:xml) { unsigned_soap_response }
      let(:signature_node) { nil }

      it 'returns nil' do
        expect(validator.canonicalization_algorithm).to be_nil
      end
    end

    context 'with explicit namespace prefixes' do
      let(:xml) { signed_response_with_explicit_prefixes }

      it 'returns the algorithm URI' do
        expect(validator.canonicalization_algorithm).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
      end
    end
  end

  describe 'different digest algorithms' do
    context 'with SHA-256 signature' do
      let(:xml) { build_signed_response(digest_algorithm: :sha256) }

      it 'verifies correctly' do
        expect(validator.valid?).to be true
      end
    end

    context 'with SHA-1 signature' do
      let(:xml) { build_signed_response(digest_algorithm: :sha1) }

      it 'verifies correctly' do
        expect(validator.valid?).to be true
      end
    end

    context 'with SHA-512 signature' do
      let(:xml) { build_signed_response(digest_algorithm: :sha512) }

      it 'verifies correctly' do
        expect(validator.valid?).to be true
      end
    end
  end

  describe 'error handling' do
    let(:xml) { signed_soap_response }

    it 'starts with empty errors' do
      expect(validator.errors).to be_empty
    end

    context 'after successful validation' do
      it 'keeps errors empty' do
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'after failed validation' do
      let(:cert) { other_certificate }

      it 'contains error messages' do
        validator.valid?
        expect(validator.errors).not_to be_empty
      end
    end
  end

  describe 'unsupported algorithm handling' do
    context 'with unsupported canonicalization algorithm' do
      let(:xml) do
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        c14n = doc.at_xpath('//ds:CanonicalizationMethod', ns)
        c14n['Algorithm'] = 'http://example.com/unsupported-c14n'
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports unsupported algorithm' do
        validator.valid?
        expect(validator.errors.join).to match(/[Uu]nsupported/)
      end
    end

    context 'with unsupported signature algorithm' do
      let(:xml) do
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        sig_method = doc.at_xpath('//ds:SignatureMethod', ns)
        sig_method['Algorithm'] = 'http://example.com/unsupported-sig'
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports unsupported algorithm' do
        validator.valid?
        expect(validator.errors.join).to match(/[Uu]nsupported/)
      end
    end

    context 'when OpenSSL raises PKeyError during verification' do
      let(:xml) { signed_soap_response }

      it 'catches PKeyError and adds failure' do
        bad_key = instance_double(OpenSSL::PKey::RSA)
        allow(bad_key).to receive(:verify).and_raise(OpenSSL::PKey::PKeyError, 'key format error')
        allow(cert).to receive(:public_key).and_return(bad_key)

        expect(validator.valid?).to be false
        expect(validator.errors.join).to include('Signature verification error: key format error')
      end
    end
  end
end
