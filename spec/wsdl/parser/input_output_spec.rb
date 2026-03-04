# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe WSDL::Parser::Input do
  let(:tempfiles) { [] }

  after do
    tempfiles.each(&:close!)
  end

  describe 'header part resolution' do
    it 'raises a typed error when soap:header is missing message attribute' do
      parser_result = parse_result(header_missing_message_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.input }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message)
        expect(error.reference_name).to be_nil
      }
    end

    it 'raises a typed error when soap:header is missing part attribute' do
      parser_result = parse_result(header_missing_part_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.input }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message_part)
        expect(error.reference_name).to be_nil
      }
    end

    it 'raises a typed error when soap:header has an empty message attribute' do
      parser_result = parse_result(header_empty_message_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.input }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message)
        expect(error.reference_name).to be_nil
      }
    end

    it 'raises a typed error when soap:header has an empty part attribute' do
      parser_result = parse_result(header_empty_part_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.input }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message_part)
        expect(error.reference_name).to be_nil
      }
    end

    it 'raises a typed error when soap:header references a missing message part' do
      parser_result = parse_result(invalid_header_part_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.input }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message_part)
        expect(error.reference_name).to eq('missing')
      }
    end

    it 'raises a typed error for output headers with missing message parts' do
      parser_result = parse_result(invalid_output_header_part_wsdl)
      operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')

      expect { operation_info.output }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message_part)
        expect(error.reference_name).to eq('missing_out')
      }
    end
  end

  def parse_result(wsdl_xml)
    WSDL::Parser::Result.new(write_wsdl_file(wsdl_xml), http_mock)
  end

  def write_wsdl_file(wsdl_xml)
    file = Tempfile.new(['parser-input', '.wsdl'])
    file.write(wsdl_xml)
    file.flush
    tempfiles << file
    file.path
  end

  def invalid_header_part_wsdl
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test"
                   name="TestService">
        <types>
          <xsd:schema targetNamespace="urn:test" elementFormDefault="qualified">
            <xsd:element name="TestRequest" type="xsd:string"/>
            <xsd:element name="TestResponse" type="xsd:string"/>
            <xsd:element name="AuthHeader" type="xsd:string"/>
          </xsd:schema>
        </types>

        <message name="TestInput">
          <part name="parameters" element="tns:TestRequest"/>
        </message>

        <message name="TestOutput">
          <part name="parameters" element="tns:TestResponse"/>
        </message>

        <message name="AuthMessage">
          <part name="auth" element="tns:AuthHeader"/>
        </message>

        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="tns:TestInput"/>
            <output message="tns:TestOutput"/>
          </operation>
        </portType>

        <binding name="TestBinding" type="tns:TestPortType">
          <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
          <operation name="TestOp">
            <soap:operation soapAction="urn:test#TestOp"/>
            <input>
              <soap:body use="literal"/>
              <soap:header message="tns:AuthMessage" part="missing" use="literal"/>
            </input>
            <output>
              <soap:body use="literal"/>
            </output>
          </operation>
        </binding>

        <service name="TestService">
          <port name="TestPort" binding="tns:TestBinding">
            <soap:address location="http://example.com/test"/>
          </port>
        </service>
      </definitions>
    XML
  end

  def header_missing_message_wsdl
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test"
                   name="TestService">
        <types>
          <xsd:schema targetNamespace="urn:test" elementFormDefault="qualified">
            <xsd:element name="TestRequest" type="xsd:string"/>
            <xsd:element name="TestResponse" type="xsd:string"/>
            <xsd:element name="AuthHeader" type="xsd:string"/>
          </xsd:schema>
        </types>

        <message name="TestInput">
          <part name="parameters" element="tns:TestRequest"/>
        </message>

        <message name="TestOutput">
          <part name="parameters" element="tns:TestResponse"/>
        </message>

        <message name="AuthMessage">
          <part name="auth" element="tns:AuthHeader"/>
        </message>

        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="tns:TestInput"/>
            <output message="tns:TestOutput"/>
          </operation>
        </portType>

        <binding name="TestBinding" type="tns:TestPortType">
          <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
          <operation name="TestOp">
            <soap:operation soapAction="urn:test#TestOp"/>
            <input>
              <soap:body use="literal"/>
              <soap:header part="auth" use="literal"/>
            </input>
            <output>
              <soap:body use="literal"/>
            </output>
          </operation>
        </binding>

        <service name="TestService">
          <port name="TestPort" binding="tns:TestBinding">
            <soap:address location="http://example.com/test"/>
          </port>
        </service>
      </definitions>
    XML
  end

  def header_missing_part_wsdl
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test"
                   name="TestService">
        <types>
          <xsd:schema targetNamespace="urn:test" elementFormDefault="qualified">
            <xsd:element name="TestRequest" type="xsd:string"/>
            <xsd:element name="TestResponse" type="xsd:string"/>
            <xsd:element name="AuthHeader" type="xsd:string"/>
          </xsd:schema>
        </types>

        <message name="TestInput">
          <part name="parameters" element="tns:TestRequest"/>
        </message>

        <message name="TestOutput">
          <part name="parameters" element="tns:TestResponse"/>
        </message>

        <message name="AuthMessage">
          <part name="auth" element="tns:AuthHeader"/>
        </message>

        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="tns:TestInput"/>
            <output message="tns:TestOutput"/>
          </operation>
        </portType>

        <binding name="TestBinding" type="tns:TestPortType">
          <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
          <operation name="TestOp">
            <soap:operation soapAction="urn:test#TestOp"/>
            <input>
              <soap:body use="literal"/>
              <soap:header message="tns:AuthMessage" use="literal"/>
            </input>
            <output>
              <soap:body use="literal"/>
            </output>
          </operation>
        </binding>

        <service name="TestService">
          <port name="TestPort" binding="tns:TestBinding">
            <soap:address location="http://example.com/test"/>
          </port>
        </service>
      </definitions>
    XML
  end

  def header_empty_message_wsdl
    header_missing_message_wsdl.sub(
      '<soap:header part="auth" use="literal"/>',
      '<soap:header message="" part="auth" use="literal"/>'
    )
  end

  def header_empty_part_wsdl
    header_missing_part_wsdl.sub(
      '<soap:header message="tns:AuthMessage" use="literal"/>',
      '<soap:header message="tns:AuthMessage" part="" use="literal"/>'
    )
  end

  def invalid_output_header_part_wsdl
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test"
                   name="TestService">
        <types>
          <xsd:schema targetNamespace="urn:test" elementFormDefault="qualified">
            <xsd:element name="TestRequest" type="xsd:string"/>
            <xsd:element name="TestResponse" type="xsd:string"/>
            <xsd:element name="AuthHeader" type="xsd:string"/>
          </xsd:schema>
        </types>

        <message name="TestInput">
          <part name="parameters" element="tns:TestRequest"/>
        </message>

        <message name="TestOutput">
          <part name="parameters" element="tns:TestResponse"/>
        </message>

        <message name="AuthMessage">
          <part name="auth" element="tns:AuthHeader"/>
        </message>

        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="tns:TestInput"/>
            <output message="tns:TestOutput"/>
          </operation>
        </portType>

        <binding name="TestBinding" type="tns:TestPortType">
          <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
          <operation name="TestOp">
            <soap:operation soapAction="urn:test#TestOp"/>
            <input>
              <soap:body use="literal"/>
            </input>
            <output>
              <soap:body use="literal"/>
              <soap:header message="tns:AuthMessage" part="missing_out" use="literal"/>
            </output>
          </operation>
        </binding>

        <service name="TestService">
          <port name="TestPort" binding="tns:TestBinding">
            <soap:address location="http://example.com/test"/>
          </port>
        </service>
      </definitions>
    XML
  end
end
