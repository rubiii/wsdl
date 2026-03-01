# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_context'

describe WSDL::Security::Verifier::ElementPositionValidator, :verifier_helpers do
  let(:document) { parse_xml(xml) }
  let(:element) { document.at_xpath(element_xpath, ns) }
  let(:validator) { described_class.new(element) }

  describe '#valid?' do
    context 'with Body element' do
      let(:element_xpath) { '//soap:Body' }

      context 'as direct child of Envelope' do
        let(:xml) { signed_soap_response }

        it 'returns true' do
          expect(validator.valid?).to be true
        end

        it 'has no errors' do
          validator.valid?
          expect(validator.errors).to be_empty
        end
      end

      context 'nested inside another element (XSW attack)' do
        let(:xml) { File.read('spec/fixtures/security/xsw_body_in_wrong_position.xml') }
        let(:element_xpath) { '//soap:Body[@wsu:Id]' }

        it 'returns false' do
          expect(validator.valid?).to be false
        end

        it 'reports position error' do
          validator.valid?
          expect(validator.errors).to include(match(/Body element must be a direct child of soap:Envelope/))
        end

        it 'includes "signature wrapping attack" in the error message' do
          validator.valid?
          expect(validator.errors.join).to include('signature wrapping attack')
        end
      end

      context 'inside Security header (XSW attack)' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                           xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
              <soap:Header>
                <wsse:Security>
                  <soap:Body wsu:Id="Body-attack">
                    <MaliciousContent/>
                  </soap:Body>
                </wsse:Security>
              </soap:Header>
              <soap:Body>
                <LegitimateContent/>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element_xpath) { '//wsse:Security/soap:Body' }

        it 'returns false' do
          expect(validator.valid?).to be false
        end

        it 'reports position error' do
          validator.valid?
          expect(validator.errors).to include(match(/Body element must be a direct child of soap:Envelope/))
        end
      end
    end

    context 'with Timestamp element' do
      context 'inside Security header' do
        let(:xml) { signed_soap_response }
        let(:element_xpath) { '//wsu:Timestamp' }

        it 'returns true' do
          expect(validator.valid?).to be true
        end

        it 'has no errors' do
          validator.valid?
          expect(validator.errors).to be_empty
        end
      end

      context 'outside Security header' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                           xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
              <soap:Header>
                <wsu:Timestamp wsu:Id="Timestamp-outside">
                  <wsu:Created>2025-01-15T12:00:00.000Z</wsu:Created>
                  <wsu:Expires>2025-01-15T12:05:00.000Z</wsu:Expires>
                </wsu:Timestamp>
                <wsse:Security/>
              </soap:Header>
              <soap:Body>
                <Data>Test</Data>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element_xpath) { '//wsu:Timestamp' }

        it 'returns false' do
          expect(validator.valid?).to be false
        end

        it 'reports position error' do
          validator.valid?
          expect(validator.errors).to include(match(/Timestamp element must be within wsse:Security header/))
        end

        it 'includes "signature wrapping attack" in the error message' do
          validator.valid?
          expect(validator.errors.join).to include('signature wrapping attack')
        end
      end

      context 'in soap:Body' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
              <soap:Header/>
              <soap:Body>
                <wsu:Timestamp wsu:Id="Timestamp-in-body">
                  <wsu:Created>2025-01-15T12:00:00.000Z</wsu:Created>
                  <wsu:Expires>2025-01-15T12:05:00.000Z</wsu:Expires>
                </wsu:Timestamp>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element_xpath) { '//wsu:Timestamp' }

        it 'returns false' do
          expect(validator.valid?).to be false
        end
      end
    end

    context 'with WS-Addressing headers' do
      let(:wsa_ns) { 'http://www.w3.org/2005/08/addressing' }

      context 'To header inside soap:Header' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsa="http://www.w3.org/2005/08/addressing">
              <soap:Header>
                <wsa:To>http://example.com/service</wsa:To>
              </soap:Header>
              <soap:Body>
                <Data>Test</Data>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element) { document.at_xpath('//wsa:To', ns.merge('wsa' => wsa_ns)) }

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end

      context 'Action header inside soap:Header' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsa="http://www.w3.org/2005/08/addressing">
              <soap:Header>
                <wsa:Action>http://example.com/action</wsa:Action>
              </soap:Header>
              <soap:Body>
                <Data>Test</Data>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element) { document.at_xpath('//wsa:Action', ns.merge('wsa' => wsa_ns)) }

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end

      context 'To header outside soap:Header (in Body)' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsa="http://www.w3.org/2005/08/addressing">
              <soap:Header/>
              <soap:Body>
                <wsa:To wsu:Id="To-attack"#{' '}
                        xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
                  http://attacker.com/service
                </wsa:To>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element) { document.at_xpath('//wsa:To', ns.merge('wsa' => wsa_ns)) }

        it 'returns false' do
          expect(validator.valid?).to be false
        end

        it 'reports position error' do
          validator.valid?
          expect(validator.errors).to include(match(/WS-Addressing header 'To' must be within soap:Header/))
        end

        it 'includes "signature wrapping attack" in the error message' do
          validator.valid?
          expect(validator.errors.join).to include('signature wrapping attack')
        end
      end

      context 'MessageID header in wrong position' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsa="http://www.w3.org/2005/08/addressing"
                           xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
              <soap:Header>
                <wsse:Security>
                  <wsa:MessageID>urn:uuid:attack-id</wsa:MessageID>
                </wsse:Security>
              </soap:Header>
              <soap:Body>
                <Data>Test</Data>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element) { document.at_xpath('//wsa:MessageID', ns.merge('wsa' => wsa_ns)) }

        # NOTE: MessageID is within Header (via Security), so this should pass
        # The check is for being within soap:Header, not directly under it
        it 'returns true (is within soap:Header hierarchy)' do
          expect(validator.valid?).to be true
        end
      end
    end

    context 'with known security elements' do
      context 'BinarySecurityToken in Security header' do
        let(:xml) { signed_soap_response }
        let(:element_xpath) { '//wsse:BinarySecurityToken' }

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end

      context 'Signature in Security header' do
        let(:xml) { signed_soap_response }
        let(:element_xpath) { '//ds:Signature' }

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end

      context 'SecurityTokenReference in Signature' do
        let(:xml) { signed_soap_response }
        let(:element) do
          document.at_xpath('//wsse:SecurityTokenReference', ns)
        end

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end
    end

    context 'with unknown elements' do
      context 'custom element in Body (normal position)' do
        let(:xml) { signed_soap_response }
        let(:element) { document.at_xpath('//soap:Body/*[1]', ns) }

        it 'returns true' do
          expect(validator.valid?).to be true
        end
      end

      context 'unknown element hidden in Security header' do
        let(:xml) do
          <<~XML
            <?xml version="1.0" encoding="UTF-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                           xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                           xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
              <soap:Header>
                <wsse:Security>
                  <MaliciousElement wsu:Id="Hidden-content">
                    <SensitiveData>attack payload</SensitiveData>
                  </MaliciousElement>
                </wsse:Security>
              </soap:Header>
              <soap:Body>
                <Data>Test</Data>
              </soap:Body>
            </soap:Envelope>
          XML
        end
        let(:element) { document.at_xpath('//wsse:Security/MaliciousElement', ns) }

        it 'returns false' do
          expect(validator.valid?).to be false
        end

        it 'reports unexpected location error' do
          validator.valid?
          expect(validator.errors).to include(match(/found in unexpected location within Security header/))
        end

        it 'includes "signature wrapping attack" in the error message' do
          validator.valid?
          expect(validator.errors.join).to include('signature wrapping attack')
        end
      end

      context 'element inside ds:Signature (expected location)' do
        let(:xml) { signed_soap_response }
        let(:element) { document.at_xpath('//ds:SignedInfo', ns) }

        it 'returns true (elements inside Signature are expected)' do
          expect(validator.valid?).to be true
        end
      end
    end
  end

  describe 'KNOWN_SECURITY_ELEMENTS constant' do
    it 'includes Timestamp' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to include('Timestamp')
    end

    it 'includes BinarySecurityToken' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to include('BinarySecurityToken')
    end

    it 'includes UsernameToken' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to include('UsernameToken')
    end

    it 'includes Signature' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to include('Signature')
    end

    it 'includes SecurityTokenReference' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to include('SecurityTokenReference')
    end

    it 'is frozen' do
      expect(described_class::KNOWN_SECURITY_ELEMENTS).to be_frozen
    end
  end

  describe 'error handling' do
    let(:xml) { signed_soap_response }
    let(:element_xpath) { '//soap:Body' }

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
      let(:xml) { File.read('spec/fixtures/security/xsw_body_in_wrong_position.xml') }
      let(:element_xpath) { '//soap:Body[@wsu:Id]' }

      it 'contains error messages' do
        validator.valid?
        expect(validator.errors).not_to be_empty
      end
    end
  end
end
