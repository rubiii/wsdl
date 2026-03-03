# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Operation do
  subject(:operation)  { described_class.new(operation_info, parser_result, http_mock) }

  let(:parser_result)  { WSDL::Parser::Result.new fixture('wsdl/temperature'), http_mock }
  let(:operation_info) { parser_result.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }

  describe '#endpoint' do
    it 'returns the SOAP endpoint' do
      expect(operation.endpoint).to eq('http://www.webservicex.net/ConvertTemperature.asmx')
    end

    it 'can be overwritten' do
      operation.endpoint = 'http://example.com'
      expect(operation.endpoint).to eq('http://example.com')
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
  end

  describe '#soap_action' do
    it 'returns the SOAP action for the operation' do
      expect(operation.soap_action).to eq('http://www.webserviceX.NET/ConvertTemp')
    end

    it 'can be overwritten' do
      operation.soap_action = 'ConvertSomething'
      expect(operation.soap_action).to eq('ConvertSomething')
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
  end

  describe '#pretty_print' do
    it 'defaults to true' do
      expect(operation.pretty_print).to be(true)
    end

    it 'can be overwritten' do
      operation.pretty_print = false
      expect(operation.pretty_print).to be(false)
    end

    it 'can be set via constructor' do
      operation = described_class.new(operation_info, parser_result, http_mock, pretty_print: false)
      expect(operation.pretty_print).to be(false)
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

    it 'can be overwritten' do
      headers = { 'SecretToken' => 'abc' }
      operation.http_headers = headers

      expect(operation.http_headers).to eq(headers)
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

  describe '#build' do
    it 'returns an example request Hash following WSDL\'s conventions' do
      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })

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

      expect(operation.build)
        .to be_equivalent_to(expected).respecting_element_order
    end

    it 'raises in strict mode when top-level elements exceed maxOccurs' do
      expect {
        apply_request(operation, strict_schema: true, body: {
          ConvertTemp: [
            {
              Temperature: 30,
              FromUnit: 'degreeCelsius',
              ToUnit: 'degreeFahrenheit'
            },
            {
              Temperature: 31,
              FromUnit: 'degreeCelsius',
              ToUnit: 'degreeFahrenheit'
            }
          ]
        })
      }.to raise_error(WSDL::RequestValidationError, /exceeds maxOccurs=1/)
    end

    it 'reflects updated body values on the next call' do
      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })
      operation.build

      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 100,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })

      expect(operation.build).to include('<ns0:Temperature>100</ns0:Temperature>')
    end

    it 'reflects SOAP version changes in the next built envelope' do
      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })

      first_namespace = Nokogiri.XML(operation.build).root.namespace.href

      operation.soap_version = '1.1'
      second_namespace = Nokogiri.XML(operation.build).root.namespace.href

      expect(first_namespace).to eq(WSDL::NS::SOAP_1_2)
      expect(second_namespace).to eq(WSDL::NS::SOAP_1_1)
    end

    it 'reflects security configuration changes on the next call' do
      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })
      operation.build

      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      }) do
        username_token('username', 'secret', digest: true)
      end

      expect(operation.build).to include('UsernameToken')
    end

    context 'with pretty_print: false' do
      let(:compact_operation) { described_class.new(operation_info, parser_result, http_mock, pretty_print: false) }

      it 'returns compact XML without indentation' do
        apply_request(compact_operation, body: {
          ConvertTemp: {
            Temperature: 30,
            FromUnit: 'degreeCelsius',
            ToUnit: 'degreeFahrenheit'
          }
        })

        xml = compact_operation.build

        # Compact XML should not have leading whitespace on lines
        expect(xml).not_to match(/^\s+</)
        # Should be on a single line
        expect(xml.strip).not_to include("\n")
      end

      it 'returns semantically equivalent XML' do
        apply_request(compact_operation, body: {
          ConvertTemp: {
            Temperature: 30,
            FromUnit: 'degreeCelsius',
            ToUnit: 'degreeFahrenheit'
          }
        })

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

        expect(compact_operation.build)
          .to be_equivalent_to(expected).respecting_element_order
      end
    end
  end

  describe '#call' do
    it 'calls the operation with a Hash of options and returns a Response' do
      http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx')

      apply_request(operation, body: {
        ConvertTemp: {
          Temperature: 30,
          FromUnit: 'degreeCelsius',
          ToUnit: 'degreeFahrenheit'
        }
      })

      response = operation.call

      expect(response).to be_a(WSDL::Response)
    end

    context 'with response verification enforcement' do
      let(:request_body) do
        {
          ConvertTemp: {
            Temperature: 30,
            FromUnit: 'degreeCelsius',
            ToUnit: 'degreeFahrenheit'
          }
        }
      end

      before do
        http_mock.fake_request('http://www.webservicex.net/ConvertTemperature.asmx', 'security/unsigned_response.xml')
      end

      it 'raises when strict verification is required and response is unsigned' do
        apply_request(operation, body: request_body) do
          verify_response
        end

        expect { operation.call }.to raise_error(WSDL::SignatureVerificationError, /does not contain a signature/)
      end

      it 'allows unsigned responses in verify_if_present mode' do
        apply_request(operation, body: request_body) do
          verify_response(mode: WSDL::Security::ResponsePolicy::MODE_IF_PRESENT)
        end

        expect(operation.call).to be_a(WSDL::Response)
      end

      it 'allows unsigned responses when verification is disabled' do
        apply_request(operation, body: request_body) do
          verify_response(mode: WSDL::Security::ResponsePolicy::MODE_DISABLED)
        end

        expect(operation.call).to be_a(WSDL::Response)
      end
    end
  end
end
