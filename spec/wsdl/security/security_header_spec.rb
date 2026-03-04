# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::SecurityHeader do
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

    # Add Subject Key Identifier extension for SKI tests
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))

    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  let(:basic_envelope) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <GetUser xmlns="http://example.com/users">
            <userId>123</userId>
          </GetUser>
        </env:Body>
      </env:Envelope>
    XML
  end

  let(:envelope_with_ws_addressing) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:wsa="http://www.w3.org/2005/08/addressing">
        <env:Header>
          <wsa:To>http://example.com/service</wsa:To>
          <wsa:From>
            <wsa:Address>http://client.example.com</wsa:Address>
          </wsa:From>
          <wsa:ReplyTo>
            <wsa:Address>http://client.example.com/callback</wsa:Address>
          </wsa:ReplyTo>
          <wsa:FaultTo>
            <wsa:Address>http://client.example.com/fault</wsa:Address>
          </wsa:FaultTo>
          <wsa:Action>http://example.com/GetUser</wsa:Action>
          <wsa:MessageID>urn:uuid:12345678-1234-1234-1234-123456789012</wsa:MessageID>
          <wsa:RelatesTo>urn:uuid:00000000-0000-0000-0000-000000000000</wsa:RelatesTo>
        </env:Header>
        <env:Body>
          <GetUser xmlns="http://example.com/users">
            <userId>123</userId>
          </GetUser>
        </env:Body>
      </env:Envelope>
    XML
  end

  let(:envelope_with_legacy_ws_addressing) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
                    xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing">
        <env:Header>
          <wsa:To>http://example.com/service</wsa:To>
          <wsa:Action>http://example.com/GetUser</wsa:Action>
          <wsa:MessageID>urn:uuid:12345678-1234-1234-1234-123456789012</wsa:MessageID>
        </env:Header>
        <env:Body>
          <GetUser xmlns="http://example.com/users">
            <userId>123</userId>
          </GetUser>
        </env:Body>
      </env:Envelope>
    XML
  end

  def parse_xml(xml)
    Nokogiri::XML(xml)
  end

  def security_node(doc)
    doc.at_xpath(
      '//wsse:Security',
      'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
    )
  end

  describe '#apply' do
    context 'with Nokogiri document input' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.timestamp(expires_in: 300)
        end
      end

      it 'accepts and signs a prebuilt Nokogiri document' do
        document = WSDL::Request::Serializer.new(
          document: WSDL::Request::Document.new,
          soap_version: '1.1',
          pretty_print: true
        ).to_document

        result = header.apply(document)
        parsed = parse_xml(result)

        expect(security_node(parsed)).not_to be_nil
      end

      it 'normalizes blank text nodes like the string input path' do
        document = parse_xml(<<~XML)
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header/>
            <env:Body>
              <GetUser xmlns="http://example.com/users">
                <userId>123</userId>
              </GetUser>
            </env:Body>
          </env:Envelope>
        XML

        result = header.apply(document)
        parsed = parse_xml(result)
        blank_text_nodes = parsed.xpath('//text()').count { |node| node.content.strip.empty? }

        expect(blank_text_nodes).to eq(0)
      end

      it 'does not mutate the original Nokogiri document' do
        document = parse_xml(<<~XML)
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header/>
            <env:Body>
              <GetUser xmlns="http://example.com/users">
                <userId>123</userId>
              </GetUser>
            </env:Body>
          </env:Envelope>
        XML
        original_blank_text_nodes = document.xpath('//text()').count { |node| node.content.strip.empty? }

        header.apply(document)

        current_blank_text_nodes = document.xpath('//text()').count { |node| node.content.strip.empty? }
        expect(current_blank_text_nodes).to eq(original_blank_text_nodes)
      end

      it 'rejects document input containing DOCTYPE' do
        document = parse_xml(<<~XML)
          <!DOCTYPE env:Envelope [
            <!ELEMENT env:Envelope ANY>
          ]>
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header/>
            <env:Body/>
          </env:Envelope>
        XML

        expect { header.apply(document) }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
      end
    end

    context 'with timestamp only' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.timestamp(expires_in: 300)
        end
      end

      it 'adds a wsse:Security element to the header' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        expect(security_node(doc)).not_to be_nil
      end

      it 'adds a wsu:Timestamp element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        timestamp = security_node(doc).at_xpath(
          'wsu:Timestamp',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        expect(timestamp).not_to be_nil
        expect(timestamp.at_xpath('wsu:Created', 'wsu' => timestamp.namespace.href)).not_to be_nil
        expect(timestamp.at_xpath('wsu:Expires', 'wsu' => timestamp.namespace.href)).not_to be_nil
      end

      it 'assigns a wsu:Id to the Timestamp' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        timestamp = security_node(doc).at_xpath(
          'wsu:Timestamp',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        wsu_id = timestamp.attribute_with_ns(
          'Id',
          'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        expect(wsu_id).not_to be_nil
        expect(wsu_id.value).to start_with('Timestamp-')
      end
    end

    context 'with username token (plain text)' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.username_token('testuser', 'testpass')
        end
      end

      it 'adds a wsse:UsernameToken element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        token = security_node(doc).at_xpath(
          'wsse:UsernameToken',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(token).not_to be_nil
      end

      it 'includes the username' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        username = security_node(doc).at_xpath(
          'wsse:UsernameToken/wsse:Username',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(username.text).to eq('testuser')
      end

      it 'includes the password with PasswordText type' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        password = security_node(doc).at_xpath(
          'wsse:UsernameToken/wsse:Password',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(password.text).to eq('testpass')
        expect(password['Type']).to include('PasswordText')
      end
    end

    context 'with username token (digest)' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.username_token('testuser', 'testpass', digest: true)
        end
      end

      it 'includes the password with PasswordDigest type' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        password = security_node(doc).at_xpath(
          'wsse:UsernameToken/wsse:Password',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(password['Type']).to include('PasswordDigest')
        expect(password.text).not_to eq('testpass') # Should be hashed
      end

      it 'includes a Nonce element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        nonce = security_node(doc).at_xpath(
          'wsse:UsernameToken/wsse:Nonce',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(nonce).not_to be_nil
        expect(nonce['EncodingType']).to include('Base64Binary')
      end

      it 'includes a Created element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        created = security_node(doc).at_xpath(
          'wsse:UsernameToken/wsu:Created',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        expect(created).not_to be_nil
      end

      it 'generates fresh nonce and created values across multiple apply calls' do
        first = parse_xml(header.apply(basic_envelope))
        second = parse_xml(header.apply(basic_envelope))

        first_nonce = security_node(first).at_xpath(
          'wsse:UsernameToken/wsse:Nonce',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )&.text
        first_token_id = security_node(first).at_xpath(
          'wsse:UsernameToken/@wsu:Id',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )&.text

        second_nonce = security_node(second).at_xpath(
          'wsse:UsernameToken/wsse:Nonce',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )&.text
        second_token_id = security_node(second).at_xpath(
          'wsse:UsernameToken/@wsu:Id',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )&.text

        expect(first_nonce).not_to eq(second_nonce)
        expect(first_token_id).not_to eq(second_token_id)
      end
    end

    context 'with X.509 signature (binary security token)' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.timestamp
          c.signature(
            certificate: certificate,
            private_key: private_key,
            key_reference: :binary_security_token
          )
        end
      end

      it 'adds a BinarySecurityToken element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        bst = security_node(doc).at_xpath(
          'wsse:BinarySecurityToken',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(bst).not_to be_nil
        expect(bst['ValueType']).to include('X509v3')
        expect(bst['EncodingType']).to include('Base64Binary')
      end

      it 'adds a Signature element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        signature = security_node(doc).at_xpath(
          'ds:Signature',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(signature).not_to be_nil
      end

      it 'includes SignedInfo with References' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        signed_info = security_node(doc).at_xpath(
          'ds:Signature/ds:SignedInfo',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        references = signed_info.xpath(
          'ds:Reference',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(references.length).to be >= 1
      end

      it 'includes SignatureValue' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        sig_value = security_node(doc).at_xpath(
          'ds:Signature/ds:SignatureValue',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(sig_value).not_to be_nil
        expect(sig_value.text).not_to be_empty
      end

      it 'includes KeyInfo referencing the BinarySecurityToken' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        key_info = security_node(doc).at_xpath(
          'ds:Signature/ds:KeyInfo',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        reference = key_info.at_xpath(
          'wsse:SecurityTokenReference/wsse:Reference',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(reference).not_to be_nil
        expect(reference['URI']).to start_with('#SecurityToken-')
        expect(reference['ValueType']).to include('X509v3')
      end
    end

    context 'with X.509 signature (issuer serial)' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.signature(
            certificate: certificate,
            private_key: private_key,
            key_reference: :issuer_serial
          )
        end
      end

      it 'does not add a BinarySecurityToken element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        bst = security_node(doc).at_xpath(
          'wsse:BinarySecurityToken',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(bst).to be_nil
      end

      it 'includes X509IssuerSerial in KeyInfo' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        issuer_serial = security_node(doc).at_xpath(
          'ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/ds:X509Data/ds:X509IssuerSerial',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(issuer_serial).not_to be_nil
      end

      it 'includes the issuer name' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        issuer_name = security_node(doc).at_xpath(
          'ds:Signature/ds:KeyInfo//ds:X509IssuerName',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(issuer_name).not_to be_nil
        expect(issuer_name.text).to include('CN=Test Certificate')
      end

      it 'includes the serial number' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        serial = security_node(doc).at_xpath(
          'ds:Signature/ds:KeyInfo//ds:X509SerialNumber',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(serial).not_to be_nil
        expect(serial.text).to eq('1')
      end
    end

    context 'with X.509 signature (subject key identifier)' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.signature(
            certificate: certificate,
            private_key: private_key,
            key_reference: :subject_key_identifier
          )
        end
      end

      it 'does not add a BinarySecurityToken element' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        bst = security_node(doc).at_xpath(
          'wsse:BinarySecurityToken',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(bst).to be_nil
      end

      it 'includes KeyIdentifier in KeyInfo' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        key_id = security_node(doc).at_xpath(
          'ds:Signature/ds:KeyInfo/wsse:SecurityTokenReference/wsse:KeyIdentifier',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#',
          'wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
        )

        expect(key_id).not_to be_nil
        expect(key_id['ValueType']).to include('X509SubjectKeyIdentifier')
      end
    end

    context 'with explicit namespace prefixes' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.signature(
            certificate: certificate,
            private_key: private_key,
            explicit_namespace_prefixes: true
          )
        end
      end

      it 'uses ds: prefix for Signature elements' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        # Check the actual element name includes the prefix
        signature = security_node(doc).at_xpath(
          'ds:Signature',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(signature.name).to eq('Signature')
        expect(signature.namespace.prefix).to eq('ds')
      end

      it 'uses ds: prefix for SignedInfo elements' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        signed_info = security_node(doc).at_xpath(
          'ds:Signature/ds:SignedInfo',
          'ds' => 'http://www.w3.org/2000/09/xmldsig#'
        )

        expect(signed_info.namespace.prefix).to eq('ds')
      end
    end

    context 'with sign_addressing enabled' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.signature(
            certificate: certificate,
            private_key: private_key,
            sign_addressing: true
          )
        end
      end

      describe 'WS-Addressing 1.0 headers (2005/08 namespace)' do
        # These tests verify each WS-Addressing header documented in ws-security.md
        # is properly signed when present

        it 'signs the wsa:To header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          to_element = doc.at_xpath(
            '//wsa:To',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = to_element.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:To should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:From header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          from_element = doc.at_xpath(
            '//wsa:From',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = from_element.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:From should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:ReplyTo header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          reply_to = doc.at_xpath(
            '//wsa:ReplyTo',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = reply_to.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:ReplyTo should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:FaultTo header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          fault_to = doc.at_xpath(
            '//wsa:FaultTo',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = fault_to.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:FaultTo should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:Action header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          action = doc.at_xpath(
            '//wsa:Action',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = action.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:Action should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:MessageID header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          message_id = doc.at_xpath(
            '//wsa:MessageID',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = message_id.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:MessageID should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end

        it 'signs the wsa:RelatesTo header' do
          result = header.apply(envelope_with_ws_addressing)
          doc = parse_xml(result)

          relates_to = doc.at_xpath(
            '//wsa:RelatesTo',
            'wsa' => 'http://www.w3.org/2005/08/addressing'
          )

          wsu_id = relates_to.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'wsa:RelatesTo should have wsu:Id for signing'
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end
      end

      describe 'WS-Addressing 2004/08 namespace (legacy)' do
        it 'signs legacy WS-Addressing headers' do
          result = header.apply(envelope_with_legacy_ws_addressing)
          doc = parse_xml(result)

          # Check that legacy namespace headers are also signed
          to_element = doc.at_xpath(
            '//wsa:To',
            'wsa' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing'
          )

          wsu_id = to_element.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil, 'Legacy wsa:To should have wsu:Id for signing'
        end
      end

      describe 'partial WS-Addressing headers' do
        let(:envelope_with_partial_addressing) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
                          xmlns:wsa="http://www.w3.org/2005/08/addressing">
              <env:Header>
                <wsa:To>http://example.com/service</wsa:To>
                <wsa:Action>http://example.com/GetUser</wsa:Action>
              </env:Header>
              <env:Body>
                <GetUser xmlns="http://example.com/users">
                  <userId>123</userId>
                </GetUser>
              </env:Body>
            </env:Envelope>
          XML
        end

        it 'only signs WS-Addressing headers that are present' do
          result = header.apply(envelope_with_partial_addressing)
          doc = parse_xml(result)
          wsu_ns = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'

          # To should be signed
          to_element = doc.at_xpath('//wsa:To', 'wsa' => 'http://www.w3.org/2005/08/addressing')
          expect(to_element.attribute_with_ns('Id', wsu_ns)).not_to be_nil

          # Action should be signed
          action = doc.at_xpath('//wsa:Action', 'wsa' => 'http://www.w3.org/2005/08/addressing')
          expect(action.attribute_with_ns('Id', wsu_ns)).not_to be_nil

          # MessageID should not exist (and thus not be signed)
          message_id = doc.at_xpath('//wsa:MessageID', 'wsa' => 'http://www.w3.org/2005/08/addressing')
          expect(message_id).to be_nil
        end
      end

      describe 'no WS-Addressing headers' do
        it 'does not fail when no WS-Addressing headers are present' do
          expect { header.apply(basic_envelope) }.not_to raise_error
        end

        it 'still signs the body' do
          result = header.apply(basic_envelope)
          doc = parse_xml(result)

          body = doc.at_xpath('//env:Body', 'env' => 'http://schemas.xmlsoap.org/soap/envelope/')
          wsu_id = body.attribute_with_ns(
            'Id',
            'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
          )

          expect(wsu_id).not_to be_nil
          expect(reference_exists_for_id?(doc, wsu_id.value)).to be true
        end
      end
    end

    context 'with sign_timestamp disabled' do
      subject(:header) { described_class.new(config) }

      let(:config) do
        WSDL::Security::Config.new.tap do |c|
          c.timestamp
          c.signature(
            certificate: certificate,
            private_key: private_key,
            sign_timestamp: false
          )
        end
      end

      it 'does not sign the timestamp' do
        result = header.apply(basic_envelope)
        doc = parse_xml(result)

        # Get the timestamp ID
        timestamp = security_node(doc).at_xpath(
          'wsu:Timestamp',
          'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        wsu_id = timestamp.attribute_with_ns(
          'Id',
          'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        )

        # Timestamp should not be in the references
        expect(reference_exists_for_id?(doc, wsu_id.value)).to be false
      end
    end

    context 'with different digest algorithms' do
      %i[sha1 sha256 sha512].each do |algorithm|
        context "with #{algorithm}" do
          subject(:header) { described_class.new(config) }

          let(:config) do
            WSDL::Security::Config.new.tap do |c|
              c.signature(
                certificate: certificate,
                private_key: private_key,
                digest_algorithm: algorithm
              )
            end
          end

          it "produces a valid signature with #{algorithm}" do
            result = header.apply(basic_envelope)

            # Verify with our verifier
            verifier = WSDL::Security::Verifier.new(result)
            expect(verifier.valid?).to be true
          end
        end
      end
    end
  end

  # Helper method to check if a reference exists for a given ID
  def reference_exists_for_id?(doc, id)
    references = doc.xpath(
      '//ds:Signature/ds:SignedInfo/ds:Reference',
      'ds' => 'http://www.w3.org/2000/09/xmldsig#'
    )

    references.any? { |ref| ref['URI'] == "##{id}" }
  end
end
