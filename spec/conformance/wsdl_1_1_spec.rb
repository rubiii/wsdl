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
      wsdl = fixture('parser/duplicate_definitions/root')
      documents = WSDL::Parser::DocumentCollection.new
      schemas = WSDL::Schema::Collection.new
      source = WSDL::Resolver::Source.validate_wsdl!(wsdl)
      loader = WSDL::Resolver::Loader.new(http_mock, sandbox_paths: [File.dirname(File.expand_path(wsdl))])
      importer = WSDL::Resolver::Importer.new(loader, documents, schemas, WSDL::ParseOptions.default)
      importer.import(source.value)

      expect { documents.messages }
        .to raise_error(WSDL::DuplicateDefinitionError) { |error|
          expect(error.component_type).to eq(:message)
        }
    end

    # https://www.w3.org/TR/wsdl#_porttypes
    it 'W11-NAME-2: port type names resolve uniquely within a document' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      operations = definition.operations('ConvertTemperature', 'ConvertTemperatureSoap').map { |o| o[:name] }
      expect(operations).to include('ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_bindings
    it 'W11-NAME-3: each binding maps to a distinct port' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      ports = definition.ports('ConvertTemperature')

      expect(ports.size).to eq(2)
      expect(ports.map { |p| p[:name] }).to contain_exactly('ConvertTemperatureSoap', 'ConvertTemperatureSoap12')
    end

    # https://www.w3.org/TR/wsdl#_ports
    it 'W11-NAME-4: port names are unique within a service' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      ports = definition.ports('ConvertTemperature')
      port_names = ports.map { |p| p[:name] }
      expect(port_names.uniq.size).to eq(port_names.size)
    end

    # https://www.w3.org/TR/wsdl#_services
    it 'W11-NAME-5: service names are unique within a document' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      services = definition.services
      service_names = services.map { |s| s[:name] }
      expect(service_names.uniq.size).to eq(service_names.size)
    end
  end

  # --------------------------------------------------------------------------
  # SOAP Binding
  # --------------------------------------------------------------------------

  describe 'SOAP Binding' do
    # https://www.w3.org/TR/wsdl#_soap:binding
    it 'W11-SOAP-1: soap:binding must be present for SOAP operations' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      expect(op_data[:input_style]).to eq('document/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:binding
    it 'W11-SOAP-2: style defaults to document when soap:binding omits style attribute' do
      definition = WSDL::Parser.parse fixture('wsdl/economic'), http_mock
      op_data = definition.operation_data('EconomicWebService', 'EconomicWebServiceSoap', 'Connect')
      expect(op_data[:input_style]).to eq('document/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:operation
    it 'W11-SOAP-3: operation style inherits from binding-level style' do
      definition = WSDL::Parser.parse fixture('wsdl/rpc_literal'), http_mock

      op1 = definition.operation_data('SampleService', 'Sample', 'op1')
      op2 = definition.operation_data('SampleService', 'Sample', 'op2')

      expect(op1[:input_style]).to eq('rpc/literal')
      expect(op2[:input_style]).to eq('rpc/literal')
    end

    # https://www.w3.org/TR/wsdl#_soap:operation
    it 'W11-SOAP-4: SOAPAction is extracted from soap:operation' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      expect(op_data[:soap_action]).to eq('http://www.webserviceX.NET/ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-5: all message parts included when parts attribute is omitted' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')

      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      expect(body_parts).not_to be_empty
      expect(body_parts.first.name).to eq('ConvertTemp')
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-6: use=encoded is detected and rejected' do
      client = WSDL::Client.new WSDL.parse(fixture('wsdl/data_exchange'), http: http_mock), http: http_mock

      expect { client.operation('DataExchange', 'DataExchange', 'submit') }
        .to raise_error(WSDL::UnsupportedStyleError, %r{rpc/encoded})
    end

    # https://www.w3.org/TR/wsdl#_soap:body
    it 'W11-SOAP-7: RPC wraps parts in an operation-named element with namespace' do
      definition = WSDL::Parser.parse fixture('wsdl/rpc_literal'), http_mock
      op_data = definition.operation_data('SampleService', 'Sample', 'op1')
      endpoint = definition.endpoint('SampleService', 'Sample')
      operation = WSDL::Operation.new(op_data, endpoint, http_mock)

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
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      endpoint = definition.endpoint('ConvertTemperature', 'ConvertTemperatureSoap')
      operation = WSDL::Operation.new(op_data, endpoint, http_mock)

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
      definition = WSDL::Parser.parse fixture('wsdl/yahoo'), http_mock
      op_data = definition.operation_data(
        'AccountServiceService', 'AccountService', 'updateStatusForManagedPublisher'
      )

      header_parts = op_data[:input][:header].map { |h| WSDL::Definition::ElementHash.new(h) }
      expect(header_parts).not_to be_empty
      expect(header_parts.map(&:name)).to include('Security')
    end

    # https://www.w3.org/TR/wsdl#_soap:address
    it 'W11-SOAP-10: endpoint address is extracted from soap:address' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      endpoint = definition.endpoint('ConvertTemperature', 'ConvertTemperatureSoap')
      expect(endpoint).to eq('http://www.webservicex.net/ConvertTemperature.asmx')
    end

    # https://www.w3.org/TR/wsdl#_bindings
    it 'W11-BIND-1: missing binding reference records build issue' do
      definition = WSDL::Parser.parse fixture('parser/unresolved_references/binding'), http_mock

      expect(definition.build_issues).not_to be_empty
      expect(definition.build_issues.any? { |issue| issue[:error].match?(/binding/i) }).to be true
    end

    # https://www.w3.org/TR/wsdl#_ports
    it 'W11-PORT-1: missing portType reference records build issue' do
      definition = WSDL::Parser.parse fixture('parser/unresolved_references/port_type'), http_mock

      expect(definition.build_issues).not_to be_empty
      expect(definition.build_issues.any? { |issue| issue[:error].match?(/port.?type/i) }).to be true
    end
  end

  # --------------------------------------------------------------------------
  # Operation Types
  # --------------------------------------------------------------------------

  describe 'Operation Types' do
    # https://www.w3.org/TR/wsdl#_request-response
    it 'W11-OP-1: request-response operations have both input and output' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')

      input_body = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      expect(op_data[:input]).not_to be_nil
      expect(input_body).not_to be_empty

      output_body = op_data[:output][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      expect(op_data[:output]).not_to be_nil
      expect(output_body).not_to be_empty
    end

    # https://www.w3.org/TR/wsdl#_messages
    it 'W11-TYPE-1: message parts with element= attribute resolve to named schema elements' do
      definition = WSDL::Parser.parse fixture('wsdl/temperature'), http_mock
      op_data = definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp')
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }

      expect(body_parts.first.name).to eq('ConvertTemp')
      expect(body_parts.first).to respond_to(:children)
    end

    # https://www.w3.org/TR/wsdl#_messages
    it 'W11-TYPE-2: message parts with type= attribute are resolved' do
      definition = WSDL::Parser.parse fixture('wsdl/rpc_literal'), http_mock
      op_data = definition.operation_data('SampleService', 'Sample', 'op1')
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }

      expect(body_parts).not_to be_empty
      expect(body_parts.first.name).to eq('in')
    end

    # https://www.w3.org/TR/wsdl#_document-n
    it 'W11-IMP-1: cross-namespace schema imports are resolved' do
      definition = WSDL::Parser.parse fixture('wsdl/rpc_literal'), http_mock
      op_data = definition.operation_data('SampleService', 'Sample', 'op3')
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }

      expect(body_parts.size).to be >= 2
    end
  end

  # --------------------------------------------------------------------------
  # WS-I Basic Profile R2304
  # --------------------------------------------------------------------------

  describe 'WS-I Basic Profile' do
    # http://www.ws-i.org/Profiles/BasicProfile-1.1-2004-08-24.html#R2304
    it 'WSI-R2304: overloaded portType operations rejected in strict mode' do
      client = WSDL::Client.new WSDL.parse(fixture('parser/operation_overloading'), http: http_mock),
        http: http_mock,
        strictness: WSDL::Strictness.on

      expect { client.operation('LookupService', 'LookupPort', 'Lookup') }
        .to raise_error(WSDL::OperationOverloadError) { |error|
          expect(error.operation_name).to eq('Lookup')
          expect(error.overload_count).to eq(2)
        }
    end
  end
end
