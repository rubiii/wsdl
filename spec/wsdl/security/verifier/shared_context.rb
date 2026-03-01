# frozen_string_literal: true

require 'spec_helper'

# Shared context for verifier component specs.
# Provides test certificates, keys, and helper methods for building test XML.
RSpec.shared_context 'verifier test helpers' do
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

  let(:other_private_key) { OpenSSL::PKey::RSA.new(2048) }

  let(:other_certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = OpenSSL::X509::Name.new([['CN', 'Other Certificate']])
    cert.issuer = cert.subject
    cert.public_key = other_private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(other_private_key, OpenSSL::Digest.new('SHA256'))
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
    build_signed_response(body_id: 'Body-test123')
  end

  let(:signed_response_with_explicit_prefixes) do
    build_signed_response(
      body_id: 'Body-explicit123',
      explicit_namespace_prefixes: true
    )
  end

  # Builds a signed SOAP response using the library
  def build_signed_response(body_id: 'Body-test123', explicit_namespace_prefixes: false, digest_algorithm: :sha256)
    envelope = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="#{body_id}">
          <GetUserResponse xmlns="http://example.com/users">
            <User>
              <Name>John Doe</Name>
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
      explicit_namespace_prefixes: explicit_namespace_prefixes,
      digest_algorithm: digest_algorithm
    )

    header = WSDL::Security::SecurityHeader.new(config)
    header.apply(envelope)
  end

  # Parses XML string into Nokogiri document
  def parse_xml(xml)
    WSDL::XML::Parser.parse(xml)
  end

  # Namespace mappings for XPath queries
  def ns
    {
      'ds' => 'http://www.w3.org/2000/09/xmldsig#',
      'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
      'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd',
      'soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
    }
  end

  # Builds a minimal signed document for testing specific components
  def build_minimal_signed_document(options = {})
    body_id = options[:body_id] || 'Body-123'
    timestamp_id = options[:timestamp_id] || 'Timestamp-456'
    token_id = options[:token_id] || 'Token-789'
    cert_data = Base64.strict_encode64(certificate.to_der)

    minimal_signed_document_xml(body_id:, timestamp_id:, token_id:, cert_data:)
  end

  def minimal_signed_document_xml(body_id:, timestamp_id:, token_id:, cert_data:)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                     xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"
                     xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
        <soap:Header>
          <wsse:Security soap:mustUnderstand="1">
            <wsu:Timestamp wsu:Id="#{timestamp_id}">
              <wsu:Created>2025-01-15T12:00:00.000Z</wsu:Created>
              <wsu:Expires>2025-01-15T12:05:00.000Z</wsu:Expires>
            </wsu:Timestamp>
            <wsse:BinarySecurityToken wsu:Id="#{token_id}"
              ValueType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3"
              EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">#{cert_data}</wsse:BinarySecurityToken>
            <ds:Signature>
              <ds:SignedInfo>
                <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                <ds:Reference URI="##{body_id}">
                  <ds:Transforms>
                    <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                  </ds:Transforms>
                  <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                  <ds:DigestValue>fakedigest==</ds:DigestValue>
                </ds:Reference>
              </ds:SignedInfo>
              <ds:SignatureValue>fakesig==</ds:SignatureValue>
              <ds:KeyInfo>
                <wsse:SecurityTokenReference>
                  <wsse:Reference URI="##{token_id}"/>
                </wsse:SecurityTokenReference>
              </ds:KeyInfo>
            </ds:Signature>
          </wsse:Security>
        </soap:Header>
        <soap:Body wsu:Id="#{body_id}">
          <Data>Test</Data>
        </soap:Body>
      </soap:Envelope>
    XML
  end
end

RSpec.configure do |config|
  config.include_context 'verifier test helpers', :verifier_helpers
end
