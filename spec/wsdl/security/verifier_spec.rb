# frozen_string_literal: true

require 'spec_helper'
require_relative 'verifier/shared_context'

describe WSDL::Security::Verifier, :verifier_helpers do
  describe '#initialize' do
    it 'accepts an XML string' do
      verifier = described_class.new(unsigned_soap_response)
      expect(verifier).to be_a(described_class)
    end

    it 'rejects a Nokogiri document' do
      doc = Nokogiri::XML(unsigned_soap_response)
      expect { described_class.new(doc) }.to raise_error(ArgumentError, /Expected String/)
    end

    it 'accepts an optional certificate' do
      verifier = described_class.new(unsigned_soap_response, certificate: certificate)
      expect(verifier.certificate).to eq(certificate)
    end

    it 'accepts an optional trust_store' do
      verifier = described_class.new(unsigned_soap_response, trust_store: :system)
      expect(verifier).to be_a(described_class)
    end

    it 'accepts an optional check_validity flag' do
      verifier = described_class.new(unsigned_soap_response, check_validity: false)
      expect(verifier).to be_a(described_class)
    end

    it 'accepts certificate as PEM string' do
      verifier = described_class.new(unsigned_soap_response, certificate: certificate.to_pem)
      expect(verifier.certificate).to be_a(OpenSSL::X509::Certificate)
    end

    it 'raises for invalid XML type' do
      expect { described_class.new(12_345) }.to raise_error(ArgumentError, /Expected String/)
    end

    it 'raises for invalid certificate type' do
      expect { described_class.new(unsigned_soap_response, certificate: 12_345) }.to raise_error(ArgumentError)
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
      let(:verifier) { described_class.new(unsigned_soap_response) }

      it 'returns false' do
        expect(verifier.valid?).to be false
      end

      it 'adds error about missing signature' do
        verifier.valid?
        expect(verifier.errors).to include('No signature found in document')
      end
    end

    context 'with valid signed response' do
      let(:verifier) { described_class.new(signed_soap_response) }

      it 'returns true' do
        expect(verifier.valid?).to be true
      end

      it 'has no errors' do
        verifier.valid?
        expect(verifier.errors).to be_empty
      end

      it 'extracts certificate from BinarySecurityToken' do
        verifier.valid?
        expect(verifier.certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end

    context 'with signature that omits SOAP Body' do
      let(:xml) { build_signed_response_without_body_reference }
      let(:verifier) { described_class.new(xml) }

      it 'returns false' do
        expect(verifier.valid?).to be false
      end

      it 'reports missing SOAP Body reference' do
        verifier.valid?
        expect(verifier.errors).to include('SignedInfo must contain a reference to the SOAP Body')
      end
    end

    context 'with SOAP 1.2 signature that omits SOAP Body' do
      let(:xml) do
        build_signed_response_without_body_reference(
          soap_namespace: WSDL::NS::SOAP_1_2
        )
      end
      let(:verifier) { described_class.new(xml) }

      it 'returns false' do
        expect(verifier.valid?).to be false
      end

      it 'reports missing SOAP Body reference' do
        verifier.valid?
        expect(verifier.errors).to include('SignedInfo must contain a reference to the SOAP Body')
      end
    end

    context 'with explicit namespace prefixes' do
      let(:verifier) { described_class.new(signed_response_with_explicit_prefixes) }

      it 'returns true for valid signature' do
        expect(verifier.valid?).to be true
      end
    end

    context 'with pretty-printed signed response' do
      let(:verifier) do
        pretty_xml = Nokogiri::XML(signed_soap_response).to_xml(indent: 2)
        described_class.new(pretty_xml)
      end

      it 'returns true for valid signature' do
        expect(verifier.valid?).to be true
      end
    end

    context 'with tampered body' do
      let(:verifier) do
        response = signed_soap_response
        doc = Nokogiri::XML(response)
        body = doc.at_xpath('//soap:Body', ns)
        body.content = 'tampered content'
        described_class.new(doc.to_xml)
      end

      it 'returns false' do
        expect(verifier.valid?).to be false
      end

      it 'reports digest mismatch error' do
        verifier.valid?
        expect(verifier.errors).to include(match(/Digest mismatch/))
      end
    end

    context 'with SignedInfo containing no references' do
      let(:verifier) do
        doc = Nokogiri::XML(signed_soap_response)
        doc.xpath('//ds:SignedInfo/ds:Reference', ns).remove
        described_class.new(doc.to_xml)
      end

      it 'returns false' do
        expect(verifier.valid?).to be false
      end

      it 'reports missing reference error' do
        verifier.valid?
        expect(verifier.errors).to include('SignedInfo must contain at least one ds:Reference')
      end
    end

    context 'with provided certificate' do
      it 'uses the provided certificate for verification' do
        verifier = described_class.new(signed_soap_response, certificate: certificate)
        expect(verifier.valid?).to be true
      end

      it 'fails with wrong certificate' do
        verifier = described_class.new(signed_soap_response, certificate: other_certificate)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include('SignatureValue verification failed')
      end
    end

    context 'caching' do
      let(:verifier) { described_class.new(signed_soap_response) }

      it 'caches the verification result' do
        first_result = verifier.valid?
        second_result = verifier.valid?
        expect(first_result).to eq(second_result)
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
      let(:verifier) { described_class.new(signed_soap_response) }

      it 'returns the IDs of signed elements' do
        ids = verifier.signed_element_ids
        expect(ids).to be_an(Array)
        expect(ids).not_to be_empty
      end

      it 'includes Body and Timestamp IDs' do
        ids = verifier.signed_element_ids
        expect(ids.any? { |id| id.start_with?('Body-') }).to be true
        expect(ids.any? { |id| id.start_with?('Timestamp-') }).to be true
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
      let(:verifier) { described_class.new(signed_soap_response) }

      it 'returns element names' do
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
        expect(verifier.signature_algorithm).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
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
        expect(verifier.digest_algorithm).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
      end
    end
  end

  describe '#timestamp_errors' do
    let(:expired_timestamp_response) do
      past_time = Time.now.utc - 7200

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                       xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
          <soap:Header>
            <wsse:Security soap:mustUnderstand="1">
              <wsu:Timestamp wsu:Id="Timestamp-123">
                <wsu:Created>#{(past_time - 300).xmlschema}</wsu:Created>
                <wsu:Expires>#{past_time.xmlschema}</wsu:Expires>
              </wsu:Timestamp>
            </wsse:Security>
          </soap:Header>
          <soap:Body>
            <Response>OK</Response>
          </soap:Body>
        </soap:Envelope>
      XML
    end

    it 'returns timestamp validation errors after timestamp checks run' do
      verifier = described_class.new(expired_timestamp_response)

      expect(verifier.timestamp_valid?).to be false
      expect(verifier.timestamp_errors).to include(match(/Timestamp has expired/))
    end

    it 'does not append duplicate errors across repeated calls' do
      verifier = described_class.new(expired_timestamp_response)
      verifier.timestamp_valid?

      first_errors = verifier.timestamp_errors
      second_errors = verifier.timestamp_errors

      expect(second_errors).to eq(first_errors)
    end
  end

  describe '#errors' do
    it 'is empty initially' do
      verifier = described_class.new(unsigned_soap_response)
      expect(verifier.errors).to be_empty
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

  describe '#certificate' do
    context 'with provided certificate' do
      it 'returns the provided certificate immediately' do
        verifier = described_class.new(unsigned_soap_response, certificate: certificate)
        expect(verifier.certificate).to eq(certificate)
      end
    end

    context 'without provided certificate' do
      it 'returns nil before verification' do
        verifier = described_class.new(signed_soap_response)
        # Certificate is extracted during verification
        expect(verifier.certificate).to be_nil
      end

      it 'returns the extracted certificate after verification' do
        verifier = described_class.new(signed_soap_response)
        verifier.valid?
        expect(verifier.certificate).to be_a(OpenSSL::X509::Certificate)
      end
    end
  end

  describe 'round-trip verification' do
    it 'verifies what was signed' do
      # Build a fresh signed document
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-roundtrip">
            <TestData>
              <Value>123</Value>
            </TestData>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp
      config.signature(certificate: certificate, private_key: private_key)

      header = WSDL::Security::SecurityHeader.new(config)
      signed_xml = header.apply(envelope)

      verifier = described_class.new(signed_xml)
      expect(verifier.valid?).to be true
      expect(verifier.signed_elements).to include('Body', 'Timestamp')
    end
  end

  describe 'with different digest algorithms' do
    %i[sha1 sha256 sha512].each do |algorithm|
      context "with #{algorithm.upcase} signed response" do
        let(:xml) { build_signed_response(digest_algorithm: algorithm) }

        it "verifies #{algorithm.upcase} signatures" do
          verifier = described_class.new(xml)
          expect(verifier.valid?).to be true
        end
      end
    end
  end

  describe 'XSW attack protection integration' do
    # These tests verify the full verification pipeline catches XSW attacks

    describe 'duplicate ID detection' do
      let(:duplicate_id_fixture) { File.read('spec/fixtures/security/xsw_duplicate_id.xml') }

      it 'rejects documents with duplicate IDs' do
        # Disable validity checking - fixture has expired certificate
        verifier = described_class.new(duplicate_id_fixture, check_validity: false)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include(match(/Duplicate element IDs detected/))
      end
    end

    describe 'signature location validation' do
      let(:signature_outside_security) { File.read('spec/fixtures/security/xsw_signature_outside_security.xml') }

      it 'rejects signatures outside Security header' do
        # Disable validity checking - fixture has expired certificate
        verifier = described_class.new(signature_outside_security, check_validity: false)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include(match(/Signature element must be within wsse:Security header/))
      end
    end

    describe 'element position validation' do
      let(:body_in_wrong_position) { File.read('spec/fixtures/security/xsw_body_in_wrong_position.xml') }

      it 'rejects Body elements in wrong position' do
        # Disable validity checking - fixture has expired certificate
        verifier = described_class.new(body_in_wrong_position, check_validity: false)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include(match(/Body element must be a direct child of soap:Envelope/))
      end
    end

    describe 'structural validation order' do
      let(:duplicate_id_fixture) { File.read('spec/fixtures/security/xsw_duplicate_id.xml') }

      it 'detects structural issues before cryptographic verification' do
        # Disable validity checking - fixture has expired certificate
        verifier = described_class.new(duplicate_id_fixture, check_validity: false)
        verifier.valid?
        # First error should be structural, not crypto-related
        expect(verifier.errors.first).to match(/Duplicate element IDs|Signature element must be/)
      end
    end
  end

  describe 'XPath injection protection' do
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
      verifier = described_class.new(response_with_reference("test'inject"))
      elements = verifier.signed_elements
      expect(elements).to eq([])
      expect(verifier.errors).to include(match(/Invalid element ID format/))
    end

    it 'finds element with valid ID' do
      verifier = described_class.new(response_with_reference('Body-123'))
      elements = verifier.signed_elements
      expect(elements).to eq(['Body'])
      expect(verifier.errors).to be_empty
    end
  end

  describe 'verification phases' do
    # These tests verify the coordinator properly sequences validation phases

    it 'runs structural validation before certificate resolution' do
      # Document with structural problem (signature outside Security)
      xml = File.read('spec/fixtures/security/xsw_signature_outside_security.xml')
      verifier = described_class.new(xml)
      verifier.valid?
      # Should fail on structure, not certificate
      expect(verifier.errors).to include(match(/Signature element must be within/))
      expect(verifier.errors).not_to include(match(/certificate/i))
    end

    it 'runs certificate resolution before reference validation' do
      # Valid structure but missing certificate
      xml = unsigned_soap_response
      verifier = described_class.new(xml)
      verifier.valid?
      # Should fail on missing signature first
      expect(verifier.errors).to include('No signature found in document')
    end

    it 'runs certificate validation after certificate resolution' do
      # Build a signed response, then verify with trust store
      # The self-signed test certificate won't be in system store
      verifier = described_class.new(signed_soap_response, trust_store: :system)
      verifier.valid?
      # Should fail on certificate chain, not structure or digest
      expect(verifier.errors).to include(match(/chain validation failed/i))
    end

    it 'runs reference validation before signature validation' do
      # This is tested implicitly - if digests don't match, we don't bother
      # with signature verification
      response = signed_soap_response
      doc = Nokogiri::XML(response)
      body = doc.at_xpath('//soap:Body', ns)
      body.content = 'tampered'
      verifier = described_class.new(doc.to_xml)
      verifier.valid?
      expect(verifier.errors).to include(match(/Digest mismatch/))
    end
  end

  describe 'certificate validation' do
    let(:expired_certificate) do
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 99
      cert.subject = OpenSSL::X509::Name.new([['CN', 'Expired Test Certificate']])
      cert.issuer = cert.subject
      cert.public_key = private_key.public_key
      cert.not_before = Time.now - 7200
      cert.not_after = Time.now - 3600 # Expired 1 hour ago
      cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
      cert
    end

    let(:expired_signed_response) do
      envelope = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header/>
          <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-expired-test">
            <TestData>Hello</TestData>
          </soap:Body>
        </soap:Envelope>
      XML

      config = WSDL::Security::Config.new
      config.timestamp
      config.signature(certificate: expired_certificate, private_key: private_key)

      header = WSDL::Security::SecurityHeader.new(config)
      header.apply(envelope)
    end

    context 'with check_validity enabled (default)' do
      it 'rejects responses signed with expired certificates' do
        verifier = described_class.new(expired_signed_response, check_validity: true)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include(match(/expired/i))
      end

      it 'accepts responses signed with valid certificates' do
        verifier = described_class.new(signed_soap_response, check_validity: true)
        expect(verifier.valid?).to be true
      end
    end

    context 'with check_validity disabled' do
      it 'accepts responses signed with expired certificates' do
        verifier = described_class.new(expired_signed_response, check_validity: false)
        expect(verifier.valid?).to be true
      end
    end

    context 'with trust_store configured' do
      it 'rejects self-signed certificates not in trust store' do
        verifier = described_class.new(signed_soap_response, trust_store: :system)
        expect(verifier.valid?).to be false
        expect(verifier.errors).to include(match(/chain validation failed/i))
      end

      it 'accepts certificates signed by trusted CA' do
        # Build CA and signed certificate
        ca_key = OpenSSL::PKey::RSA.new(2048)
        ca_cert = OpenSSL::X509::Certificate.new
        ca_cert.version = 2
        ca_cert.serial = 1000
        ca_cert.subject = OpenSSL::X509::Name.new([['CN', 'Test CA']])
        ca_cert.issuer = ca_cert.subject
        ca_cert.public_key = ca_key.public_key
        ca_cert.not_before = Time.now - 86_400
        ca_cert.not_after = Time.now + 86_400

        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = ca_cert
        ef.issuer_certificate = ca_cert
        ca_cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
        ca_cert.sign(ca_key, OpenSSL::Digest.new('SHA256'))

        # Create certificate signed by CA
        signed_key = OpenSSL::PKey::RSA.new(2048)
        signed_cert = OpenSSL::X509::Certificate.new
        signed_cert.version = 2
        signed_cert.serial = 1001
        signed_cert.subject = OpenSSL::X509::Name.new([['CN', 'Signed Cert']])
        signed_cert.issuer = ca_cert.subject
        signed_cert.public_key = signed_key.public_key
        signed_cert.not_before = Time.now - 3600
        signed_cert.not_after = Time.now + 3600
        signed_cert.sign(ca_key, OpenSSL::Digest.new('SHA256'))

        # Build signed response with CA-signed certificate
        envelope = <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header/>
            <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-ca-test">
              <TestData>Hello</TestData>
            </soap:Body>
          </soap:Envelope>
        XML

        config = WSDL::Security::Config.new
        config.timestamp
        config.signature(certificate: signed_cert, private_key: signed_key)

        header = WSDL::Security::SecurityHeader.new(config)
        ca_signed_response = header.apply(envelope)

        verifier = described_class.new(ca_signed_response, trust_store: [ca_cert])
        expect(verifier.valid?).to be true
      end
    end
  end
end
