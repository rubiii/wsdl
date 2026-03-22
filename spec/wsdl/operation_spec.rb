# frozen_string_literal: true

require 'tempfile'

RSpec.describe WSDL::Operation do
  subject(:operation)  { described_class.new(operation_info, parser_result, http_mock) }

  let(:parser_result)  { WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock }
  let(:operation_info) { parser_result.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }
  let(:tempfiles) { [] }

  after do
    tempfiles.each(&:close!)
  end

  describe '#endpoint' do
    it 'returns the SOAP endpoint' do
      expect(operation.endpoint).to eq('http://www.webservicex.net/ConvertTemperature.asmx')
    end

    it 'can be overwritten' do
      operation.endpoint = 'http://example.com'
      expect(operation.endpoint).to eq('http://example.com')
    end

    it 'raises on empty string' do
      expect { operation.endpoint = '' }.to raise_error(ArgumentError, /non-empty String/)
    end

    it 'raises on non-string' do
      expect { operation.endpoint = nil }.to raise_error(ArgumentError, /non-empty String/)
    end
  end

  describe '#soap_version' do
    it 'returns the SOAP version determined by the service and port' do
      expect(operation.soap_version).to eq('1.2')
    end

    it 'can be overwritten' do
      operation.soap_version = '1.1'
      expect(operation.soap_version).to eq('1.1')
    end

    it 'raises on unsupported version' do
      expect { operation.soap_version = '2.0' }.to raise_error(ArgumentError, /'1.1' or '1.2'/)
    end
  end

  describe '#soap_action' do
    it 'returns the SOAP action for the operation' do
      expect(operation.soap_action).to eq('http://www.webserviceX.NET/ConvertTemp')
    end

    it 'can be overwritten' do
      operation.soap_action = 'ConvertSomething'
      expect(operation.soap_action).to eq('ConvertSomething')
    end

    it 'can be set to nil' do
      operation.soap_action = nil
      expect(operation.soap_action).to be_nil
    end

    it 'raises on non-string' do
      expect { operation.soap_action = 123 }.to raise_error(ArgumentError, /String or nil/)
    end
  end

  describe '#name' do
    it 'returns the operation name from the WSDL' do
      expect(operation.name).to eq('ConvertTemp')
    end
  end

  describe '#output_namespace' do
    it 'returns nil for document/literal operations' do
      expect(operation.output_namespace).to be_nil
    end

    context 'with an RPC/literal operation' do
      let(:parser_result) { WSDL::Parser::Result.parse fixture('wsdl/rpc_literal'), http_mock }
      let(:operation_info) { parser_result.operation('SampleService', 'Sample', 'op1') }

      it 'returns the binding output namespace' do
        expect(operation.output_namespace).to eq('http://apiNamespace.com')
      end
    end
  end

  describe '#input_element_name' do
    it 'returns the input body element name' do
      expect(operation.input_element_name).to eq('ConvertTemp')
    end

    context 'when the element name differs from the operation name' do
      let(:parser_result) { WSDL::Parser::Result.parse fixture('wsdl/equifax'), http_mock }
      let(:operation_info) { parser_result.operation('canadav2', 'canadaHttpPortV2', 'startTransaction') }

      it 'returns the element name, not the operation name' do
        expect(operation.name).to eq('startTransaction')
        expect(operation.input_element_name).to eq('InitialRequest')
      end
    end
  end

  describe '#input_style' do
    it 'returns the input style for the operation' do
      expect(operation.input_style).to eq('document/literal')
    end
  end

  describe '#output_style' do
    it 'returns the output style for the operation' do
      expect(operation.output_style).to eq('document/literal')
    end
  end

  describe '#encoding' do
    it 'defaults to UTF-8' do
      expect(operation.encoding).to eq('UTF-8')
    end

    it 'can be overwritten' do
      operation.encoding = 'US-ASCII'
      expect(operation.encoding).to eq('US-ASCII')
    end

    it 'raises on empty string' do
      expect { operation.encoding = '' }.to raise_error(ArgumentError, /non-empty String/)
    end

    it 'raises on non-string' do
      expect { operation.encoding = nil }.to raise_error(ArgumentError, /non-empty String/)
    end
  end

  describe '#format_xml' do
    it 'defaults to true' do
      expect(operation.format_xml).to be(true)
    end

    it 'can be overwritten' do
      operation.format_xml = false
      expect(operation.format_xml).to be(false)
    end

    it 'can be set via config' do
      config = WSDL::Config.new(format_xml: false)
      operation = described_class.new(operation_info, parser_result, http_mock, config:)
      expect(operation.format_xml).to be(false)
    end

    it 'per-operation override takes precedence over config' do
      config = WSDL::Config.new(format_xml: false)
      operation = described_class.new(operation_info, parser_result, http_mock, config:)
      operation.format_xml = true
      expect(operation.format_xml).to be(true)
    end

    it 'reverts to config default after reset!' do
      operation.format_xml = false
      operation.reset!
      expect(operation.format_xml).to be(true)
    end
  end

  describe '#http_headers' do
    it 'returns a Hash of HTTP headers for a SOAP 1.2 operation' do
      expect(operation.http_headers).to eq(
        'Content-Type' => 'application/soap+xml;charset=UTF-8;action="http://www.webserviceX.NET/ConvertTemp"'
      )
    end

    it 'returns a Hash of HTTP headers for a SOAP 1.1 operation' do
      soap11_operation_info = parser_result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      operation = described_class.new(soap11_operation_info, parser_result, http_mock)

      expect(operation.http_headers).to eq(
        'SOAPAction' => '"http://www.webserviceX.NET/ConvertTemp"',
        'Content-Type' => 'text/xml;charset=UTF-8'
      )
    end

    it 'merges custom headers on top of auto-generated headers' do
      operation.http_headers = { 'X-Auth-Token' => 'abc' }

      expect(operation.http_headers).to include(
        'Content-Type' => 'application/soap+xml;charset=UTF-8;action="http://www.webserviceX.NET/ConvertTemp"',
        'X-Auth-Token' => 'abc'
      )
    end

    it 'lets custom headers override auto-generated ones' do
      operation.http_headers = { 'Content-Type' => 'text/plain' }

      expect(operation.http_headers['Content-Type']).to eq('text/plain')
    end

    it 'clears custom headers on reset!' do
      operation.http_headers = { 'X-Auth-Token' => 'abc' }
      operation.reset!

      expect(operation.http_headers).not_to include('X-Auth-Token')
    end

    it 'reflects updated SOAP settings on the next call' do
      operation.http_headers

      operation.soap_version = '1.1'
      operation.soap_action = 'ConvertSomething'
      operation.encoding = 'US-ASCII'

      expect(operation.http_headers).to eq(
        'SOAPAction' => '"ConvertSomething"',
        'Content-Type' => 'text/xml;charset=US-ASCII'
      )
    end
  end

  describe '#example_request' do
    it 'returns an example request Hash following WSDL\'s conventions' do
      expect(request_template(operation, section: :body)).to eq(
        ConvertTemp: {
          Temperature: 'double',
          FromUnit: 'string',
          ToUnit: 'string'
        }
      )
    end
  end

  describe '#prepared?' do
    it 'returns false before prepare is called' do
      expect(operation.prepared?).to be(false)
    end

    it 'returns true after prepare is called' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      expect(operation.prepared?).to be(true)
    end

    it 'returns false after reset!' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      operation.reset!

      expect(operation.prepared?).to be(false)
    end
  end

  describe '#prepare' do
    it 'raises when called twice without reset!' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      expect {
        operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 100)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
        end
      }.to raise_error(WSDL::RequestDslError, /already called/)
    end

    it 'succeeds after reset!' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      operation.reset!

      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 100)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      expect(operation.to_xml).to include('<ns0:Temperature>100</ns0:Temperature>')
    end
  end

  describe '#to_xml' do
    it 'returns an example request Hash following WSDL\'s conventions' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      expected = Nokogiri.XML(%(
        <env:Envelope
            xmlns:ns0="http://www.webserviceX.NET/"
            xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Header/>
          <env:Body>
            <ns0:ConvertTemp>
              <ns0:Temperature>30</ns0:Temperature>
              <ns0:FromUnit>degreeCelsius</ns0:FromUnit>
              <ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>
            </ns0:ConvertTemp>
          </env:Body>
        </env:Envelope>
      ))

      expect(operation.to_xml)
        .to be_equivalent_to(expected).respecting_element_order
    end

    it 'raises in strict mode when top-level elements exceed maxOccurs' do
      expect {
        operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 30)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
            tag('ConvertTemp') do
              tag('Temperature', 31)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
        end
      }.to raise_error(WSDL::RequestValidationError, /exceeds maxOccurs=1/)
    end

    context 'with unqualified schema elements' do
      it 'rejects namespaced child elements when schema expects unqualified form' do
        op = WSDL::Client.new(fixture('wsdl/document_literal_wrapped'))
          .operation('SampleService', 'Sample', 'op1')

        expect {
          op.prepare do
            xmlns('api', 'http://apiNamespace.com')
            body do
              tag('op1') do
                tag('api:in') do
                  tag('data1', 1)
                  tag('data2', 2)
                end
              end
            end
          end
        }.to raise_error(
          WSDL::RequestValidationError,
          /Element "api:in" must be unqualified \(no namespace\) for element "in" under "op1"/
        )
      end

      it 'rejects namespaced nested elements when schema expects unqualified form' do
        op = WSDL::Client.new(fixture('wsdl/document_literal_wrapped'))
          .operation('SampleService', 'Sample', 'op1')

        expect {
          op.prepare do
            xmlns('api', 'http://apiNamespace.com')
            body do
              tag('op1') do
                tag('in') do
                  tag('api:data1', 1)
                  tag('data2', 2)
                end
              end
            end
          end
        }.to raise_error(
          WSDL::RequestValidationError,
          /Element "api:data1" must be unqualified \(no namespace\) for element "data1" under "in"/
        )
      end

      it 'accepts unqualified elements where schema expects unqualified form' do
        op = WSDL::Client.new(fixture('wsdl/document_literal_wrapped'))
          .operation('SampleService', 'Sample', 'op1')

        op.prepare do
          body do
            tag('op1') do
              tag('in') do
                tag('data1', 1)
                tag('data2', 2)
              end
            end
          end
        end

        expect(op.to_xml).to include('<in>')
        expect(op.to_xml).to include('<data1>1</data1>')
      end

      it 'rejects namespaced top-level body elements when schema expects unqualified form' do
        op = WSDL::Client.new(fixture('wsdl/rpc_literal'))
          .operation('SampleService', 'Sample', 'op1')

        expect {
          op.prepare do
            xmlns('api', 'http://apiNamespace.com')
            body do
              tag('api:in') do
                tag('data1', 1)
                tag('data2', 2)
              end
            end
          end
        }.to raise_error(
          WSDL::RequestValidationError,
          /Element "api:in" must be unqualified \(no namespace\) for element "in" in body/
        )
      end

      it 'allows namespaced unqualified elements in relaxed mode' do
        op = WSDL::Client.new(fixture('wsdl/document_literal_wrapped'), strictness: WSDL::Strictness.off)
          .operation('SampleService', 'Sample', 'op1')

        op.prepare do
          xmlns('api', 'http://apiNamespace.com')
          body do
            tag('op1') do
              tag('api:in') do
                tag('api:data1', 1)
                tag('data2', 2)
              end
            end
          end
        end

        xml = op.to_xml
        expect(xml).to include('<api:in>')
        expect(xml).to include('<api:data1>1</api:data1>')
      end
    end

    it 'reflects updated body values on the next call' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end
      operation.to_xml

      operation.reset!
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 100)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      expect(operation.to_xml).to include('<ns0:Temperature>100</ns0:Temperature>')
    end

    it 'reflects SOAP version changes in the next built envelope' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      first_namespace = Nokogiri.XML(operation.to_xml).root.namespace.href

      operation.soap_version = '1.1'
      second_namespace = Nokogiri.XML(operation.to_xml).root.namespace.href

      expect(first_namespace).to eq(WSDL::NS::SOAP_1_2)
      expect(second_namespace).to eq(WSDL::NS::SOAP_1_1)
    end

    it 'reflects security configuration changes on the next call' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end
      operation.to_xml

      operation.reset!
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
        ws_security do
          username_token('username', 'secret', digest: true)
        end
      end

      expect(operation.to_xml).to include('UsernameToken')
    end

    it 'passes a serialized document directly to SecurityHeader when outbound security is configured' do
      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
        ws_security do
          username_token('username', 'secret')
        end
      end

      security_header = instance_spy(WSDL::Security::SecurityHeader)
      serialized_document = nil
      allow(WSDL::Security::SecurityHeader).to receive(:new).and_return(security_header)
      allow(security_header).to receive(:apply) do |xml|
        serialized_document = xml
        '<signed/>'
      end

      operation.to_xml

      expect(WSDL::Security::SecurityHeader).to have_received(:new).with(instance_of(WSDL::Security::Config))
      expect(security_header).to have_received(:apply)
      expect(serialized_document).to be_a(Nokogiri::XML::Document)
    end

    context 'with format_xml: false' do
      let(:compact_operation) { described_class.new(operation_info, parser_result, http_mock, config: WSDL::Config.new(format_xml: false)) }

      it 'returns compact XML without indentation' do
        compact_operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 30)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
        end

        xml = compact_operation.to_xml

        # Compact XML should not have leading whitespace on lines
        expect(xml).not_to match(/^\s+</)
        # Should be on a single line
        expect(xml.strip).not_to include("\n")
      end

      it 'returns semantically equivalent XML' do
        compact_operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 30)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
        end

        expected = Nokogiri.XML(%(
          <env:Envelope
              xmlns:ns0="http://www.webserviceX.NET/"
              xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Header/>
            <env:Body>
              <ns0:ConvertTemp>
                <ns0:Temperature>30</ns0:Temperature>
                <ns0:FromUnit>degreeCelsius</ns0:FromUnit>
                <ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>
              </ns0:ConvertTemp>
            </env:Body>
          </env:Envelope>
        ))

        expect(compact_operation.to_xml)
          .to be_equivalent_to(expected).respecting_element_order
      end
    end

    context 'with Strictness.off fallback behavior' do
      it 'still raises for non-schema unresolved references' do
        parser_result = parse_result(header_missing_part_wsdl)
        operation_info = parser_result.operation('TestService', 'TestPort', 'TestOp')
        relaxed_operation = described_class.new(operation_info, parser_result, http_mock,
                                                config: WSDL::Config.new(strictness: WSDL::Strictness.off))

        expect {
          relaxed_operation.prepare do
            tag('TestRequest', 'value')
          end
        }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
          expect(error.reference_type).to eq(:message_part)
        }
      end
    end
  end

  describe '#invoke' do
    it 'calls the operation with a Hash of options and returns a Response' do
      http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx')

      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      response = operation.invoke

      expect(response).to be_a(WSDL::Response)
    end

    context 'with response size limiting' do
      def prepare_convert_temp(operation)
        operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 30)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
        end
      end

      it 'raises ResourceLimitError when response exceeds max_response_size' do
        large_body = 'x' * 1024
        http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx')

        # Override the fake to return a large body
        allow(http_mock).to receive(:post).and_return(
          WSDL::HTTPResponse.new(status: 200, body: large_body)
        )

        limits = WSDL::Limits.new(max_response_size: 512)
        config = WSDL::Config.new(limits:)
        op = described_class.new(operation_info, parser_result, http_mock, config:)

        prepare_convert_temp(op)

        expect { op.invoke }.to raise_error(WSDL::ResourceLimitError) { |error|
          expect(error.limit_name).to eq(:max_response_size)
          expect(error.limit_value).to eq(512)
          expect(error.actual_value).to eq(1024)
        }
      end

      it 'does not raise when response is within the limit' do
        http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx')
        prepare_convert_temp(operation)

        expect { operation.invoke }.not_to raise_error
      end

      it 'does not raise when max_response_size is nil (disabled)' do
        large_body = 'x' * (20 * 1024 * 1024)

        allow(http_mock).to receive(:post).and_return(
          WSDL::HTTPResponse.new(status: 200, body: large_body)
        )

        limits = WSDL::Limits.new(max_response_size: nil)
        config = WSDL::Config.new(limits:)
        op = described_class.new(operation_info, parser_result, http_mock, config:)

        prepare_convert_temp(op)

        expect { op.invoke }.not_to raise_error
      end
    end

    context 'with response verification enforcement' do
      def prepare_with_security(operation, &security_block)
        operation.prepare do
          body do
            tag('ConvertTemp') do
              tag('Temperature', 30)
              tag('FromUnit', 'degreeCelsius')
              tag('ToUnit', 'degreeFahrenheit')
            end
          end
          ws_security(&security_block)
        end
      end

      before do
        http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx', 'security/unsigned_response.xml')
      end

      it 'raises when strict verification is required and response is unsigned' do
        prepare_with_security(operation) do
          verify_response
        end

        expect { operation.invoke }.to raise_error(WSDL::SignatureVerificationError, /does not contain a signature/)
      end

      it 'allows unsigned responses in verify_if_present mode' do
        prepare_with_security(operation) do
          verify_response(mode: WSDL::Security::ResponsePolicy::MODE_IF_PRESENT)
        end

        expect(operation.invoke).to be_a(WSDL::Response)
      end

      it 'allows unsigned responses when verification is disabled' do
        prepare_with_security(operation) do
          verify_response(mode: WSDL::Security::ResponsePolicy::MODE_DISABLED)
        end

        expect(operation.invoke).to be_a(WSDL::Response)
      end
    end
  end

  def parse_result(wsdl_xml)
    WSDL::Parser::Result.parse(write_wsdl_file(wsdl_xml), http_mock)
  end

  def write_wsdl_file(wsdl_xml)
    file = Tempfile.new(['operation-spec', '.wsdl'])
    file.write(wsdl_xml)
    file.flush
    tempfiles << file
    file.path
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

  describe '#to_xml without prepare' do
    it 'raises RequestDefinitionError when contract has elements but prepare was not called' do
      expect { operation.to_xml }
        .to raise_error(WSDL::RequestDefinitionError, /requires a request definition/)
    end
  end
end
