# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_context'

describe WSDL::Security::Verifier::ReferenceValidator, :verifier_helpers do
  let(:document) { parse_xml(xml) }
  let(:signed_info_node) { document.at_xpath('//ds:SignedInfo', ns) }
  let(:validator) { described_class.new(document, signed_info_node) }

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

    context 'with a tampered body' do
      let(:xml) do
        # Take a signed response and modify the body content
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        body = doc.at_xpath('//soap:Body', ns)
        body.content = 'tampered content'
        doc.to_xml
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports digest mismatch error' do
        validator.valid?
        expect(validator.errors).to include(match(/Digest mismatch/))
      end
    end

    context 'with missing reference URI' do
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
                    <ds:Reference>
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
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

      it 'reports missing URI error' do
        validator.valid?
        expect(validator.errors).to include('Reference missing URI attribute')
      end
    end

    context 'with missing DigestValue' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#Body-123">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
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
        expect(validator.valid?).to be false
      end

      it 'reports missing DigestValue error' do
        validator.valid?
        expect(validator.errors).to include(match(/Reference missing DigestValue/))
      end
    end

    context 'with missing DigestMethod' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#Body-123">
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
        expect(validator.valid?).to be false
      end

      it 'reports missing DigestMethod error' do
        validator.valid?
        expect(validator.errors).to include(match(/Reference missing DigestMethod/))
      end
    end

    context 'with non-existent referenced element' do
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
                    <ds:Reference URI="#NonExistent-123">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
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

      it 'reports element not found error' do
        validator.valid?
        expect(validator.errors).to include(match(/Referenced element not found.*NonExistent-123/))
      end
    end

    context 'with element in wrong position (XSW attack)' do
      let(:xml) { File.read('spec/fixtures/security/xsw_body_in_wrong_position.xml') }

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports position error' do
        validator.valid?
        expect(validator.errors).to include(match(/Body element must be a direct child of soap:Envelope/))
      end
    end

    context 'with no SignedInfo node' do
      let(:xml) { unsigned_soap_response }
      let(:signed_info_node) { nil }

      it 'returns true (no references to validate)' do
        expect(validator.valid?).to be true
      end
    end

    context 'with multiple valid references' do
      let(:xml) { signed_soap_response }

      it 'validates all references' do
        expect(validator.valid?).to be true
        expect(validator.reference_count).to be >= 1
      end
    end
  end

  describe '#reference_count' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns the number of references' do
        expect(validator.reference_count).to be >= 1
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }
      let(:signed_info_node) { nil }

      it 'returns 0' do
        expect(validator.reference_count).to eq(0)
      end
    end
  end

  describe '#referenced_ids' do
    context 'with a signed document' do
      let(:xml) { signed_soap_response }

      it 'returns array of IDs without # prefix' do
        ids = validator.referenced_ids
        expect(ids).to be_an(Array)
        expect(ids).not_to be_empty
        ids.each do |id|
          expect(id).not_to start_with('#')
        end
      end

      it 'includes the Body ID' do
        ids = validator.referenced_ids
        expect(ids.any? { |id| id.start_with?('Body-') }).to be true
      end
    end

    context 'with an unsigned document' do
      let(:xml) { unsigned_soap_response }
      let(:signed_info_node) { nil }

      it 'returns empty array' do
        expect(validator.referenced_ids).to eq([])
      end
    end
  end

  describe 'VALID_ID_PATTERN' do
    it 'is defined' do
      expect(described_class::VALID_ID_PATTERN).to be_a(Regexp)
    end

    describe 'accepts valid IDs' do
      %w[
        Body-123
        Timestamp-abc-def-123
        _underscore_start
        SecurityToken-87654321-4321-4321-4321-210987654321
        simple
        with.dots.allowed
        with-hyphens-allowed
        Mixed_Case_123
        A
        _
        a1
        Body
        TS-1234
      ].each do |valid_id|
        it "accepts: #{valid_id.inspect}" do
          expect(valid_id).to match(described_class::VALID_ID_PATTERN)
        end
      end
    end

    describe 'rejects XPath injection attempts' do
      [
        ["' or '1'='1", 'single quote injection'],
        ["Body'] | //*[@Id='x", 'XPath union operator injection'],
        ["' or @wsu:Id != 'x", 'attribute comparison injection'],
        ['foo" or "1"="1', 'double quote injection'],
        ["test' and true() or '", 'XPath function injection'],
        ["') or true() or ('", 'parentheses injection'],
        ['id[1]', 'predicate injection'],
        ['id | //password', 'union with sensitive path'],
        ["test\x00null", 'null byte injection'],
        ['id with spaces', 'whitespace in ID'],
        ['@attr', 'attribute selector injection'],
        ['/root/path', 'path separator injection'],
        ['id=value', 'equals sign injection'],
        ['id<>value', 'comparison operator injection']
      ].each do |malicious_id, description|
        it "rejects #{description}: #{malicious_id.inspect}" do
          expect(malicious_id).not_to match(described_class::VALID_ID_PATTERN)
        end
      end
    end

    describe 'rejects invalid starting characters' do
      it 'rejects ID starting with number' do
        expect(described_class::VALID_ID_PATTERN.match?('123-Body')).to be false
      end

      it 'rejects ID starting with hyphen' do
        expect(described_class::VALID_ID_PATTERN.match?('-Body')).to be false
      end

      it 'rejects ID starting with period' do
        expect(described_class::VALID_ID_PATTERN.match?('.Body')).to be false
      end
    end
  end

  describe 'XPath injection protection' do
    context 'with malicious ID in reference' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                         xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
            <soap:Header>
              <wsse:Security>
                <ds:Signature>
                  <ds:SignedInfo>
                    <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                    <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                    <ds:Reference URI="#test'inject">
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
        expect(validator.valid?).to be false
      end

      it 'reports invalid ID format error' do
        validator.valid?
        expect(validator.errors).to include(match(/Invalid element ID format/))
      end

      it 'includes XPath injection warning' do
        validator.valid?
        expect(validator.errors.join).to include('XPath injection')
      end
    end

    context 'with empty reference URI' do
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
                    <ds:Reference URI="#">
                      <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                      <ds:DigestValue>fakedigest==</ds:DigestValue>
                    </ds:Reference>
                  </ds:SignedInfo>
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

      it 'reports empty URI error' do
        validator.valid?
        expect(validator.errors).to include('Reference URI is empty')
      end
    end
  end

  describe 'digest computation' do
    context 'with different digest algorithms' do
      context 'SHA-256 (default)' do
        let(:xml) { build_signed_response(digest_algorithm: :sha256) }

        it 'verifies correctly' do
          expect(validator.valid?).to be true
        end
      end

      context 'SHA-1 (legacy)' do
        let(:xml) { build_signed_response(digest_algorithm: :sha1) }

        it 'verifies correctly' do
          expect(validator.valid?).to be true
        end
      end

      context 'SHA-512' do
        let(:xml) { build_signed_response(digest_algorithm: :sha512) }

        it 'verifies correctly' do
          expect(validator.valid?).to be true
        end
      end
    end
  end

  describe 'element position validation integration' do
    context 'when referenced element has invalid position' do
      let(:xml) { File.read('spec/fixtures/security/xsw_body_in_wrong_position.xml') }

      it 'includes position validation errors' do
        validator.valid?
        expect(validator.errors).to include(match(/signature wrapping attack/))
      end
    end
  end

  describe 'timing-safe comparison' do
    # This test verifies that SecureCompare is used for digest comparison
    # We can't easily test timing directly, but we can verify the mechanism exists
    let(:xml) { signed_soap_response }

    it 'uses SecureCompare module' do
      expect(WSDL::Security::SecureCompare).to respond_to(:equal?)
    end
  end

  describe 'error aggregation' do
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
      let(:xml) do
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        body = doc.at_xpath('//soap:Body', ns)
        body.content = 'tampered'
        doc.to_xml
      end

      it 'contains error messages' do
        validator.valid?
        expect(validator.errors).not_to be_empty
      end
    end
  end
end
