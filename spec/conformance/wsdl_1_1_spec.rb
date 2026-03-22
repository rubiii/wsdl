# frozen_string_literal: true

# Tests verifying conformance to normative requirements from the
# W3C WSDL 1.1 specification (https://www.w3.org/TR/wsdl).
#
# Each test references an assertion ID documented in W3C_CONFORMANCE_ASSERTIONS.md.

RSpec.describe 'WSDL 1.1 conformance' do
  # --------------------------------------------------------------------------
  # Document Structure
  # --------------------------------------------------------------------------

  describe 'Document Structure' do
    # https://www.w3.org/TR/wsdl#_messages
    it 'W11-NAME-1: duplicate message names across imports raise DuplicateDefinitionError' do
      result = WSDL::Parser::Result.parse fixture('parser/duplicate_definitions/root'), http_mock

      expect { result.documents.messages }
        .to raise_error(WSDL::DuplicateDefinitionError) { |error|
          expect(error.component_type).to eq(:message)
        }
    end

    # https://www.w3.org/TR/wsdl#_porttypes
    it 'W11-NAME-2: port type names resolve uniquely within a document' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operations = result.operations('ConvertTemperature', 'ConvertTemperatureSoap')
      expect(operations).to include('ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_bindings
    it 'W11-NAME-3: each binding maps to a distinct port' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      ports = result.services['ConvertTemperature'][:ports]

      expect(ports.size).to eq(2)
      expect(ports.keys).to contain_exactly('ConvertTemperatureSoap', 'ConvertTemperatureSoap12')
      expect(ports.values.map { |p| p[:type] }.uniq.size).to eq(2)
    end

    # https://www.w3.org/TR/wsdl#_ports
    it 'W11-NAME-4: port names are unique within a service' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      ports = result.services['ConvertTemperature'][:ports]
      expect(ports.keys.uniq.size).to eq(ports.keys.size)
    end

    # https://www.w3.org/TR/wsdl#_services
    it 'W11-NAME-5: service names are unique within a document' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      services = result.services
      expect(services.keys.uniq.size).to eq(services.keys.size)
    end
  end

  # --------------------------------------------------------------------------
  # SOAP Binding
  # --------------------------------------------------------------------------

  describe 'SOAP Binding' do
    # https://www.w3.org/TR/wsdl#_soap:binding
    it 'W11-SOAP-1: soap:binding must be present for SOAP operations' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      expect(operation_info.input_style).to eq('document/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:binding
    it 'W11-SOAP-2: style defaults to document when soap:binding omits style attribute' do
      result = WSDL::Parser::Result.parse fixture('wsdl/economic'), http_mock
      operation_info = result.operation('EconomicWebService', 'EconomicWebServiceSoap', 'Connect')
      expect(operation_info.input_style).to eq('document/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:operation
    it 'W11-SOAP-3: operation style inherits from binding-level style' do
      result = WSDL::Parser::Result.parse fixture('wsdl/rpc_literal'), http_mock

      op1 = result.operation('SampleService', 'Sample', 'op1')
      op2 = result.operation('SampleService', 'Sample', 'op2')

      expect(op1.input_style).to eq('rpc/literal')
      expect(op2.input_style).to eq('rpc/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:operation
    it 'W11-SOAP-4: SOAPAction is extracted from soap:operation' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      expect(operation_info.soap_action).to eq('http://www.webserviceX.NET/ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-5: all message parts included when parts attribute is omitted' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')

      body_parts = operation_info.input.body_parts
      expect(body_parts).not_to be_empty
      expect(body_parts.first.name).to eq('ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-6: use=encoded is detected and rejected' do
      client = WSDL::Client.new fixture('wsdl/data_exchange'), http: http_mock

      expect { client.operation('DataExchange', 'DataExchange', 'submit') }
        .to raise_error(WSDL::UnsupportedStyleError, %r{rpc/encoded})
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-7: RPC wraps parts in an operation-named element with namespace' do
      result = WSDL::Parser::Result.parse fixture('wsdl/rpc_literal'), http_mock
      operation_info = result.operation('SampleService', 'Sample', 'op1')
      operation = WSDL::Operation.new(operation_info, result, http_mock)

      operation.prepare do
        body do
          tag('in') do
            tag('data1', 24)
            tag('data2', 36)
          end
        end
      end

      doc = Nokogiri::XML(operation.to_xml)
      body = doc.root.element_children.find { |c| c.name == 'Body' }
      wrapper = body.element_children.first

      expect(wrapper.name).to eq('op1')
      expect(wrapper.namespace.href).to eq('http://apiNamespace.com')
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-8: document parts appear directly under Body without wrapper' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      operation = WSDL::Operation.new(operation_info, result, http_mock)

      operation.prepare do
        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      doc = Nokogiri::XML(operation.to_xml)
      body = doc.root.element_children.find { |c| c.name == 'Body' }
      first_child = body.element_children.first

      expect(first_child.name).to eq('ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_soap:header
    it 'W11-SOAP-9: header parts are resolved from soap:header' do
      result = WSDL::Parser::Result.parse fixture('wsdl/yahoo'), http_mock
      operation_info = result.operation(
        'AccountServiceService', 'AccountService', 'updateStatusForManagedPublisher'
      )

      header_parts = operation_info.input.header_parts
      expect(header_parts).not_to be_empty
      expect(header_parts.map(&:name)).to include('Security')
    end

    # https://www.w3.org/TR/wsdl#_soap:address
    it 'W11-SOAP-10: endpoint address is extracted from soap:address' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      expect(operation_info.endpoint).to eq('http://www.webservicex.net/ConvertTemperature.asmx')
    end

    # https://www.w3.org/TR/wsdl#_bindings
    it 'W11-BIND-1: missing binding reference raises UnresolvedReferenceError' do
      result = WSDL::Parser::Result.parse fixture('parser/unresolved_references/binding'), http_mock

      expect { result.operations('BadService', 'BadPort') }
        .to raise_error(WSDL::UnresolvedReferenceError) { |error|
          expect(error.reference_type).to eq(:binding)
        }
    end

    # https://www.w3.org/TR/wsdl#_ports
    it 'W11-PORT-1: missing portType reference raises UnresolvedReferenceError' do
      result = WSDL::Parser::Result.parse fixture('parser/unresolved_references/port_type'), http_mock

      expect { result.operation('BadService', 'BadPort', 'Ping') }
        .to raise_error(WSDL::UnresolvedReferenceError) { |error|
          expect(error.reference_type).to eq(:port_type)
        }
    end
  end

  # --------------------------------------------------------------------------
  # Operation Types
  # --------------------------------------------------------------------------

  describe 'Operation Types' do
    # https://www.w3.org/TR/wsdl#_request-response
    it 'W11-OP-1: request-response operations have both input and output' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')

      expect(operation_info.input).not_to be_nil
      expect(operation_info.input.body_parts).not_to be_empty
      expect(operation_info.output).not_to be_nil
      expect(operation_info.output.body_parts).not_to be_empty
    end

    # https://www.w3.org/TR/wsdl#_messages
    it 'W11-TYPE-1: message parts with element= attribute resolve to named schema elements' do
      result = WSDL::Parser::Result.parse fixture('wsdl/temperature'), http_mock
      operation_info = result.operation('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      body_parts = operation_info.input.body_parts

      expect(body_parts.first.name).to eq('ConvertTemp')
      expect(body_parts.first).to respond_to(:children)
    end

    # https://www.w3.org/TR/wsdl#_messages
    it 'W11-TYPE-2: message parts with type= attribute are resolved' do
      result = WSDL::Parser::Result.parse fixture('wsdl/rpc_literal'), http_mock
      operation_info = result.operation('SampleService', 'Sample', 'op1')
      body_parts = operation_info.input.body_parts

      expect(body_parts).not_to be_empty
      expect(body_parts.first.name).to eq('in')
    end

    # https://www.w3.org/TR/wsdl#_document-n
    it 'W11-IMP-1: cross-namespace schema imports are resolved' do
      result = WSDL::Parser::Result.parse fixture('wsdl/rpc_literal'), http_mock
      operation_info = result.operation('SampleService', 'Sample', 'op3')
      body_parts = operation_info.input.body_parts

      expect(body_parts.size).to be >= 2
    end
  end

  # --------------------------------------------------------------------------
  # WS-I Basic Profile R2304
  # --------------------------------------------------------------------------

  describe 'WS-I Basic Profile' do
    # http://www.ws-i.org/Profiles/BasicProfile-1.1-2004-08-24.html#R2304
    it 'WSI-R2304: overloaded portType operations rejected in strict mode' do
      result = WSDL::Parser::Result.parse fixture('parser/operation_overloading'), http_mock,
                                          strictness: WSDL::Strictness.on

      expect { result.operation('LookupService', 'LookupPort', 'Lookup') }
        .to raise_error(WSDL::OperationOverloadError) { |error|
          expect(error.operation_name).to eq('Lookup')
          expect(error.port_type_name).to eq('LookupPortType')
          expect(error.overload_count).to eq(2)
        }
    end
  end
end
