# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::Verifier do
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

  let(:unsigned_soap_response) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body>
          <GetUserResponse xmlns="http://example.com/users">
            <User>
              <Name>John Doe</Name>
            </User>
          </GetUserResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  let(:signed_soap_response) do
    # Build a properly signed response using the library itself
    envelope = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-test123">
          <GetUserResponse xmlns="http://example.com/users">
            <User>
              <Name>John Doe</Name>
            </User>
          </GetUserResponse>
        </soap:Body>
      </soap:Envelope>
    XML

    # Apply security header with signature
    config = WSDL::Security::Config.new
    config.timestamp
    config.signature(certificate: certificate, private_key: private_key)

    header = WSDL::Security::SecurityHeader.new(config)
    header.apply(envelope)
  end

  let(:signed_response_with_explicit_prefixes) do
    envelope = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-explicit123">
          <GetUserResponse xmlns="http://example.com/users">
            <User>
              <Name>Jane Doe</Name>
            </User>
          </GetUserResponse>
        </soap:Body>
      </soap:Envelope>
    XML

    config = WSDL::Security::Config.new
    config.timestamp
    config.signature(
      certificate: certificate,
      private_key: private_key,
      explicit_namespace_prefixes: true
    )

    header = WSDL::Security::SecurityHeader.new(config)
    header.apply(envelope)
  end

  describe '#initialize' do
    it 'accepts an XML string' do
      verifier = described_class.new(unsigned_soap_response)
      expect(verifier).to be_a(described_class)
    end

    it 'accepts a Nokogiri document' do
      doc = Nokogiri::XML(unsigned_soap_response)
      verifier = described_class.new(doc)
      expect(verifier).to be_a(described_class)
    end

    it 'accepts an optional certificate' do
      verifier = described_class.new(unsigned_soap_response, certificate: certificate)
      expect(verifier.certificate).to eq(certificate)
    end

    it 'accepts certificate as PEM string' do
      verifier = described_class.new(unsigned_soap_response, certificate: certificate.to_pem)
      expect(verifier.certificate).to be_a(OpenSSL::X509::Certificate)
    end

    it 'raises for invalid XML type' do
      expect {
        described_class.new(12_345)
      }.to raise_error(ArgumentError, /Expected String or Nokogiri::XML::Document/)
    end
  end

  describe '#signature_present?' do
    it 'returns false for unsigned response' do
      verifier = described_class.new(unsigned_soap_response)
      expect(verifier.signature_present?).to be false
    end

    it 'returns true for signed response' do
      verifier = described_class.new(signed_soap_response)
      expect(verifier.signature_present?).to be true
    end

    it 'returns true for response with explicit namespace prefixes' do
      verifier = described_class.new(signed_response_with_explicit_prefixes)
      expect(verifier.signature_present?).to be true
    end
  end

  describe '#valid?' do
    context 'with unsigned response' do
      it 'returns false' do
        verifier = described_class.new(unsigned_soap_response)
        expect(verifier.valid?).to be false
      end

      it 'adds error about missing signature' do
        verifier = described_class.new(unsigned_soap_response)
        verifier.valid?
        expect(verifier.errors).to include('No signature found in document')
      end
    end

    context 'with valid signed response' do
      it 'returns true' do
        verifier = described_class.new(signed_soap_response)
        expect(verifier.valid?).to be true
      end

      it 'has no errors' do
        verifier = described_class.new(signed_soap_response)
        verifier.valid?
        expect(verifier.errors).to be_empty
      end

      it 'extracts certificate from BinarySecurityToken' do
        verifier = described_class.new(signed_soap_response)
        verifier.valid?
        expect(verifier.certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'with explicit namespace prefixes' do
      it 'returns true for valid signature' do
        verifier = described_class.new(signed_response_with_explicit_prefixes)
        expect(verifier.valid?).to be true
      end
    end

    context 'with tampered body' do
      it 'returns false' do
        tampered = signed_soap_response.gsub('John Doe', 'Jane Doe')
        verifier = described_class.new(tampered)
        expect(verifier.valid?).to be false
      end

      it 'reports digest mismatch error' do
        tampered = signed_soap_response.gsub('John Doe', 'Jane Doe')
        verifier = described_class.new(tampered)
        verifier.valid?
        expect(verifier.errors.any? { |e| e.include?('Digest mismatch') }).to be true
      end
    end

    context 'with provided certificate' do
      it 'uses the provided certificate for verification' do
        verifier = described_class.new(signed_soap_response, certificate: certificate)
        expect(verifier.valid?).to be true
      end

      it 'fails with wrong certificate' do
        wrong_key = OpenSSL::PKey::RSA.new(2048)
        wrong_cert = OpenSSL::X509::Certificate.new
        wrong_cert.version = 2
        wrong_cert.serial = 999
        wrong_cert.subject = OpenSSL::X509::Name.new([['CN', 'Wrong Certificate']])
        wrong_cert.issuer = wrong_cert.subject
        wrong_cert.public_key = wrong_key.public_key
        wrong_cert.not_before = Time.now
        wrong_cert.not_after = Time.now + 3600
        wrong_cert.sign(wrong_key, OpenSSL::Digest.new('SHA256'))

        verifier = described_class.new(signed_soap_response, certificate: wrong_cert)
        expect(verifier.valid?).to be false
      end
    end

    context 'caching' do
      it 'caches the verification result' do
        verifier = described_class.new(signed_soap_response)
        result1 = verifier.valid?
        result2 = verifier.valid?
        expect(result1).to eq(result2)
      end
    end
  end

  describe '#signed_element_ids' do
    context 'with unsigned response' do
      it 'returns empty array' do
        verifier = described_class.new(unsigned_soap_response)
        expect(verifier.signed_element_ids).to eq([])
      end
    end

    context 'with signed response' do
      it 'returns the IDs of signed elements' do
        verifier = described_class.new(signed_soap_response)
        ids = verifier.signed_element_ids
        expect(ids).to be_an(Array)
        expect(ids.length).to be >= 1
      end

      it 'includes Body and Timestamp IDs' do
        verifier = described_class.new(signed_soap_response)
        ids = verifier.signed_element_ids
        expect(ids.any? { |id| id.start_with?('Body') || id.include?('Body') }).to be true
        expect(ids.any? { |id| id.start_with?('Timestamp') || id.include?('Timestamp') }).to be true
      end
    end
  end

  describe '#signed_elements' do
    context 'with unsigned response' do
      it 'returns empty array' do
        verifier = described_class.new(unsigned_soap_response)
        expect(verifier.signed_elements).to eq([])
      end
    end

    context 'with signed response' do
      it 'returns element names' do
        verifier = described_class.new(signed_soap_response)
        elements = verifier.signed_elements
        expect(elements).to include('Body')
        expect(elements).to include('Timestamp')
      end
    end
  end

  describe '#signature_algorithm' do
    context 'with unsigned response' do
      it 'returns nil' do
        verifier = described_class.new(unsigned_soap_response)
        expect(verifier.signature_algorithm).to be_nil
      end
    end

    context 'with signed response' do
      it 'returns the signature algorithm URI' do
        verifier = described_class.new(signed_soap_response)
        expect(verifier.signature_algorithm).to include('rsa-sha256')
      end
    end
  end

  describe '#digest_algorithm' do
    context 'with unsigned response' do
      it 'returns nil' do
        verifier = described_class.new(unsigned_soap_response)
        expect(verifier.digest_algorithm).to be_nil
      end
    end

    context 'with signed response' do
      it 'returns the digest algorithm URI' do
        verifier = described_class.new(signed_soap_response)
        expect(verifier.digest_algorithm).to include('sha256')
      end
    end
  end

  describe '#errors' do
    it 'is empty initially' do
      verifier = described_class.new(unsigned_soap_response)
      expect(verifier.errors).to eq([])
    end

    it 'populates after failed verification' do
      verifier = described_class.new(unsigned_soap_response)
      verifier.valid?
      expect(verifier.errors).not_to be_empty
    end

    it 'remains empty after successful verification' do
      verifier = described_class.new(signed_soap_response)
      verifier.valid?
      expect(verifier.errors).to be_empty
    end
  end

  describe 'with different digest algorithms' do
    context 'SHA-1 signed response' do
      let(:sha1_signed_response) do
        envelope = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header/>
            <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-sha1">
              <Response>Data</Response>
            </soap:Body>
          </soap:Envelope>
        XML

        config = WSDL::Security::Config.new
        config.signature(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha1
        )

        header = WSDL::Security::SecurityHeader.new(config)
        header.apply(envelope)
      end

      it 'verifies SHA-1 signatures' do
        verifier = described_class.new(sha1_signed_response)
        expect(verifier.valid?).to be true
      end
    end

    context 'SHA-512 signed response' do
      let(:sha512_signed_response) do
        envelope = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header/>
            <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-sha512">
              <Response>Data</Response>
            </soap:Body>
          </soap:Envelope>
        XML

        config = WSDL::Security::Config.new
        config.signature(
          certificate: certificate,
          private_key: private_key,
          digest_algorithm: :sha512
        )

        header = WSDL::Security::SecurityHeader.new(config)
        header.apply(envelope)
      end

      it 'verifies SHA-512 signatures' do
        verifier = described_class.new(sha512_signed_response)
        expect(verifier.valid?).to be true
      end
    end
  end

  describe 'round-trip verification' do
    it 'verifies what was signed' do
      # This test ensures the signing and verification are compatible
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-roundtrip">
            <ComplexResponse xmlns="http://example.com/test">
              <Items>
                <Item id="1">First</Item>
                <Item id="2">Second</Item>
              </Items>
              <Total>2</Total>
            </ComplexResponse>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp(expires_in: 300)
      config.signature(
        certificate: certificate,
        private_key: private_key,
        digest_algorithm: :sha256
      )

      header = WSDL::Security::SecurityHeader.new(config)
      signed_xml = header.apply(envelope)

      verifier = described_class.new(signed_xml)
      expect(verifier.valid?).to be true
      expect(verifier.signed_elements).to include('Body')
      expect(verifier.signed_elements).to include('Timestamp')
    end
  end

  describe 'XPath injection protection' do
    # Test the ID validation directly via the private method
    # This is more reliable than going through the full verification flow
    let(:verifier) { described_class.new(unsigned_soap_response) }

    describe 'VALID_ID_PATTERN constant' do
      it 'is defined for ID validation' do
        expect(described_class::VALID_ID_PATTERN).to be_a(Regexp)
      end
    end

    context 'with XPath injection attempts' do
      # These malicious IDs attempt to break out of the XPath string context
      # and inject additional XPath expressions
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
          # Test the pattern directly
          expect(malicious_id).not_to match(described_class::VALID_ID_PATTERN)

          # Also verify it adds an error when validated
          verifier.send(:valid_element_id?, malicious_id)
          expect(verifier.errors).to include(match(/Invalid element ID format/))
        end
      end
    end

    context 'with valid IDs' do
      # These are legitimate WS-Security style IDs that should be accepted
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
        it "accepts valid ID: #{valid_id.inspect}" do
          expect(valid_id).to match(described_class::VALID_ID_PATTERN)

          result = verifier.send(:valid_element_id?, valid_id)
          expect(result).to be true
          expect(verifier.errors).to be_empty
        end
      end
    end

    context 'with edge cases' do
      it 'rejects empty ID and records error' do
        result = verifier.send(:valid_element_id?, '')
        expect(result).to be false
        expect(verifier.errors).to include('Reference URI is empty')
      end

      it 'rejects nil ID and records error' do
        result = verifier.send(:valid_element_id?, nil)
        expect(result).to be false
        expect(verifier.errors).to include('Reference URI is empty')
      end

      it 'rejects ID starting with number' do
        expect(described_class::VALID_ID_PATTERN).not_to match('123-Body')

        verifier.send(:valid_element_id?, '123-Body')
        expect(verifier.errors).to include(match(/Invalid element ID format/))
      end

      it 'rejects ID starting with hyphen' do
        expect(described_class::VALID_ID_PATTERN).not_to match('-Body')
      end

      it 'rejects ID starting with period' do
        expect(described_class::VALID_ID_PATTERN).not_to match('.Body')
      end
    end

    context 'integration with signed_elements' do
      # This tests that the protection works through the public API
      def response_with_reference(id)
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
                    <ds:Reference URI="##{id}">
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

      it 'returns empty for malicious ID and records error' do
        # Use an ID that's valid XML but contains XPath injection
        malicious_verifier = described_class.new(response_with_reference("test'inject"))
        elements = malicious_verifier.signed_elements

        expect(elements).to eq([])
        expect(malicious_verifier.errors).to include(match(/Invalid element ID format/))
      end

      it 'finds element with valid ID' do
        valid_verifier = described_class.new(response_with_reference('Body-123'))
        elements = valid_verifier.signed_elements

        expect(elements).to eq(['Body'])
        expect(valid_verifier.errors).to be_empty
      end
    end
  end
end
