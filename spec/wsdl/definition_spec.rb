# frozen_string_literal: true

RSpec.describe WSDL::Definition do
  subject(:definition) { WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock) }

  describe '#services' do
    it 'returns all services with port names' do
      expect(definition.services).to eq([
        {
          name: 'AuthenticationWebServiceImplService',
          ports: ['AuthenticationWebServiceImplPort']
        }
      ])
    end
  end

  describe '#ports' do
    it 'returns all ports with service context and endpoint' do
      ports = definition.ports
      expect(ports).to eq([
        {
          service: 'AuthenticationWebServiceImplService',
          name: 'AuthenticationWebServiceImplPort',
          endpoint: 'http://example.com/validation/1.0/AuthenticationService'
        }
      ])
    end

    it 'filters by service name' do
      expect(definition.ports('AuthenticationWebServiceImplService').size).to eq(1)
      expect(definition.ports('NonExistent')).to eq([])
    end
  end

  describe '#operations' do
    it 'returns all operations with full context' do
      ops = definition.operations
      expect(ops.size).to eq(1)
      expect(ops.first).to include(
        service: 'AuthenticationWebServiceImplService',
        port: 'AuthenticationWebServiceImplPort',
        name: 'authenticate',
        style: 'document/literal'
      )
    end

    it 'filters by service and port' do
      ops = definition.operations('AuthenticationWebServiceImplService', 'AuthenticationWebServiceImplPort')
      expect(ops.size).to eq(1)
    end

    it 'returns empty for non-existent filters' do
      expect(definition.operations('NonExistent', 'NonExistent')).to eq([])
    end

    context 'with multi-operation WSDL' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/interhome'), http_mock) }

      it 'returns all operations across ports' do
        ops = definition.operations
        expect(ops.size).to be > 1
      end

      it 'filters to a single port' do
        ops = definition.operations('WebService', 'WebServiceSoap')
        soap12_ops = definition.operations('WebService', 'WebServiceSoap12')

        expect(ops.size).to eq(soap12_ops.size)
      end
    end

    context 'with consistent output shape' do
      it 'always includes service and port keys regardless of filters' do
        all_ops = definition.operations
        filtered = definition.operations('AuthenticationWebServiceImplService',
          'AuthenticationWebServiceImplPort')

        expect(all_ops.first.keys).to eq(filtered.first.keys)
      end
    end
  end

  describe '#input' do
    it 'returns developer-friendly element structure' do
      elements = definition.input('authenticate')

      expect(elements).to be_an(Array)
      expect(elements).not_to be_empty
      expect(elements.first).to include(name: 'authenticate', type: 'complex', required: true)
    end

    it 'uses human-readable type strings' do
      elements = definition.input('authenticate')
      types = collect_all_types(elements)

      expect(types).to all(be_a(String))
      expect(types).not_to include(a_string_matching(/\A\w+:/))
    end

    it 'does not include namespace or XSD noise' do
      elements = definition.input('authenticate')
      all_keys = collect_all_keys(elements)

      expect(all_keys).not_to include(:namespace, :form, :xsd_type, :complex_type_id, :min_occurs, :max_occurs)
    end

    it 'includes required flag' do
      elements = definition.input('authenticate')
      flat = flatten_elements(elements)

      flat.each do |el|
        expect(el).to have_key(:required)
        expect(el[:required]).to be(true).or be(false)
      end
    end

    it 'includes array flag only for non-singular elements' do
      elements = definition.input('authenticate')
      flat = flatten_elements(elements)

      flat.each do |el|
        expect(el[:array]).to be true if el.key?(:array)
      end
    end

    it 'auto-resolves service and port for single-service WSDLs' do
      expect(definition.input('authenticate')).to eq(
        definition.input('AuthenticationWebServiceImplService', 'AuthenticationWebServiceImplPort', 'authenticate')
      )
    end

    it 'raises for unknown operations' do
      expect {
        definition.input('nonexistent')
      }.to raise_error(ArgumentError, /Unknown operation/)
    end

    it 'raises with wrong argument count' do
      expect {
        definition.input('svc', 'port')
      }.to raise_error(ArgumentError, /1 argument.*3 arguments/)
    end
  end

  describe '#input_header' do
    it 'returns header elements' do
      headers = definition.input_header('authenticate')
      expect(headers).to be_an(Array)
    end
  end

  describe '#output' do
    it 'returns developer-friendly output structure' do
      elements = definition.output('authenticate')

      expect(elements).to be_an(Array)
      expect(elements).not_to be_empty
    end

    it 'returns empty array when operation has no output' do
      notify_op = {
        'name' => 'Notify', 'input_name' => nil, 'soap_action' => nil, 'soap_version' => '1.1',
        'input_style' => 'document/literal', 'output_style' => nil,
        'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
        'schema_complete' => true, 'input' => { 'header' => [], 'body' => [] }, 'output' => nil
      }
      one_way_def = described_class.new(
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'operations' => { 'Notify' => notify_op }
              }
            }
          }
        }
      )

      expect(one_way_def.output('Svc', 'Port', 'Notify')).to eq([])
      expect(one_way_def.output_header('Svc', 'Port', 'Notify')).to eq([])
    end
  end

  describe '#output_header' do
    it 'returns output header elements' do
      headers = definition.output_header('authenticate')
      expect(headers).to be_an(Array)
    end
  end

  describe '#operation_data' do
    it 'returns full internal operation hash' do
      data = definition.operation_data('authenticate')

      expect(data).to include(
        'name' => 'authenticate',
        'input_style' => 'document/literal',
        'soap_version' => a_kind_of(String)
      )
      expect(data['input']).to have_key('body')
      expect(data['input']).to have_key('header')
    end

    it 'accepts explicit service, port, operation' do
      data = definition.operation_data('AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort', 'authenticate')
      expect(data['name']).to eq('authenticate')
    end
  end

  describe '#endpoint' do
    it 'returns the endpoint URL for a service and port' do
      expect(definition.endpoint('AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort'))
        .to eq('http://example.com/validation/1.0/AuthenticationService')
    end
  end

  describe '#port_type' do
    it 'resolves namespace index to URI string' do
      uri = definition.port_type('AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort')

      expect(uri).to be_a(String)
      expect(uri).to eq('http://schemas.xmlsoap.org/wsdl/soap/')
    end
  end

  describe 'auto-resolution' do
    context 'with multiple services' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/interhome'), http_mock) }

      it 'raises when auto-resolving with multiple ports' do
        expect {
          definition.input('Search')
        }.to raise_error(ArgumentError, /Cannot auto-resolve port/)
      end

      it 'works with explicit service and port' do
        elements = definition.input('WebService', 'WebServiceSoap', 'Search')
        expect(elements).to be_an(Array)
      end
    end
  end

  describe '#to_dsl' do
    it 'generates a body section for a simple operation' do
      dsl = definition.to_dsl('authenticate')

      expect(dsl).to include('body do')
      expect(dsl).to include("tag('")
      expect(dsl).to include('end')
    end

    it 'generates tag calls with type placeholders for simple elements' do
      dsl = definition.to_dsl('authenticate')

      expect(dsl).to match(/tag\('[^']+', '[^']+'\)/)
    end

    it 'generates nested tags for complex elements' do
      dsl = definition.to_dsl('authenticate')

      expect(dsl).to match(/tag\('[^']+'\) do/)
    end

    it 'omits empty sections' do
      dsl = definition.to_dsl('authenticate')

      # The authentication fixture has no header parts
      expect(dsl).not_to include('header do')
    end

    it 'auto-resolves service and port' do
      expect(definition.to_dsl('authenticate')).to eq(
        definition.to_dsl('AuthenticationWebServiceImplService',
          'AuthenticationWebServiceImplPort', 'authenticate')
      )
    end

    context 'with header elements' do
      subject(:definition) do
        described_class.new(
          'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
          'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
          'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
          'services' => {
            'Svc' => {
              'ports' => {
                'Port' => {
                  'type' => 0, 'endpoint' => 'http://x',
                  'operations' => {
                    'Op' => {
                      'name' => 'Op', 'input_name' => nil, 'soap_action' => nil, 'soap_version' => '1.1',
                      'input_style' => 'document/literal', 'output_style' => nil,
                      'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                      'schema_complete' => true,
                      'input' => { 'header' => [simple_element('Token')], 'body' => [simple_element('Data')] },
                      'output' => nil
                    }
                  }
                }
              }
            }
          }
        )
      end

      it 'generates both header and body sections' do
        dsl = definition.to_dsl('Op')

        expect(dsl).to include("header do\n  tag('Token', 'string')\nend")
        expect(dsl).to include("body do\n  tag('Data', 'string')\nend")
      end
    end
  end

  context 'with bronto fixture' do
    subject(:definition) { WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock) }

    let(:service) { 'BrontoSoapApiImplService' }
    let(:port) { 'BrontoSoapApiImplPort' }

    describe '#input' do
      it 'projects complex nested elements with arrays' do
        elements = definition.input(service, port, 'addLogins')

        top = elements.first
        expect(top).to include(name: 'addLogins', type: 'complex', required: true)
        expect(top).not_to have_key(:array)

        accounts = top[:children].find { |c| c[:name] == 'accounts' }
        expect(accounts).to include(type: 'complex', required: false, array: true)

        contact_info = accounts[:children].find { |c| c[:name] == 'contactInformation' }
        expect(contact_info).to include(type: 'complex', required: false)
        expect(contact_info).not_to have_key(:array)

        username = accounts[:children].find { |c| c[:name] == 'username' }
        expect(username).to include(type: 'string', required: false)
        expect(username).not_to have_key(:children)
      end
    end

    describe '#input_header' do
      it 'projects header elements' do
        headers = definition.input_header(service, port, 'addLogins')

        expect(headers).not_to be_empty
        session = headers.first
        expect(session).to include(name: 'sessionHeader', type: 'complex', required: true)
        expect(session[:children].first).to include(name: 'sessionId', type: 'string')
      end
    end

    describe '#to_dsl' do
      it 'generates header and body sections for an operation with both' do
        dsl = definition.to_dsl(service, port, 'addLogins')

        expect(dsl).to include('header do')
        expect(dsl).to include("tag('sessionHeader') do")
        expect(dsl).to include("tag('sessionId', 'string')")
        expect(dsl).to include('body do')
        expect(dsl).to include("tag('addLogins') do")
        expect(dsl).to include("tag('accounts') do")
        expect(dsl).to include("tag('username', 'string')")
      end
    end
  end

  describe '#to_h port-level defaults' do
    it 'includes port-level defaults in serialized output' do
      port = definition.to_h.dig('services', 'AuthenticationWebServiceImplService',
        'ports', 'AuthenticationWebServiceImplPort')
      expect(port).to have_key('defaults')
      expect(port['defaults']).to include('soap_version', 'input_style')

      op = port['operations']['authenticate']
      expect(op).not_to have_key('soap_version')
      expect(op).not_to have_key('input_style')
    end
  end

  describe 'port-level defaults at read time' do
    let(:empty_msg) { { 'header' => [], 'body' => [] } }

    it 'merges defaults into operations via operation_data' do
      compact_hash = {
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'defaults' => { 'soap_version' => '1.1', 'input_style' => 'document/literal' },
                'operations' => {
                  'Op1' => {
                    'name' => 'Op1', 'input_name' => nil, 'soap_action' => nil,
                    'output_style' => 'document/literal',
                    'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                    'schema_complete' => true, 'input' => empty_msg, 'output' => empty_msg
                  }
                }
              }
            }
          }
        }
      }

      restored = described_class.from_h(compact_hash)
      op = restored.operation_data('Svc', 'Port', 'Op1')

      expect(op['soap_version']).to eq('1.1')
      expect(op['input_style']).to eq('document/literal')
    end

    it 'merges defaults into overloaded operations' do
      compact_hash = {
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'defaults' => { 'soap_version' => '1.1', 'schema_complete' => true },
                'operations' => {
                  'Lookup' => [
                    {
                      'name' => 'Lookup', 'input_name' => 'ById', 'soap_action' => nil,
                      'input_style' => 'document/literal', 'output_style' => 'document/literal',
                      'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                      'input' => empty_msg, 'output' => empty_msg
                    },
                    {
                      'name' => 'Lookup', 'input_name' => 'ByName', 'soap_action' => nil,
                      'input_style' => 'document/literal', 'output_style' => 'document/literal',
                      'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                      'input' => empty_msg, 'output' => empty_msg
                    }
                  ]
                }
              }
            }
          }
        }
      }

      restored = described_class.from_h(compact_hash)
      by_id = restored.operation_data('Svc', 'Port', 'Lookup', input_name: 'ById')
      by_name = restored.operation_data('Svc', 'Port', 'Lookup', input_name: 'ByName')

      expect(by_id['soap_version']).to eq('1.1')
      expect(by_id['schema_complete']).to be true
      expect(by_name['soap_version']).to eq('1.1')
      expect(by_name['schema_complete']).to be true
    end

    it 'works without a defaults key' do
      plain_hash = {
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'operations' => {
                  'Op1' => {
                    'name' => 'Op1', 'input_name' => nil, 'soap_action' => nil,
                    'soap_version' => '1.1', 'input_style' => 'document/literal',
                    'output_style' => 'document/literal',
                    'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                    'schema_complete' => true, 'input' => { 'header' => [], 'body' => [] },
                    'output' => { 'header' => [], 'body' => [] }
                  }
                }
              }
            }
          }
        }
      }

      restored = described_class.from_h(plain_hash)
      op = restored.operation_data('Svc', 'Port', 'Op1')

      expect(op['soap_version']).to eq('1.1')
    end

    it 'merges defaults into operations yielded by #operations' do
      compact_hash = {
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'defaults' => { 'soap_version' => '1.1', 'input_style' => 'document/literal' },
                'operations' => {
                  'Op1' => {
                    'name' => 'Op1', 'input_name' => nil, 'soap_action' => 'urn:op1',
                    'output_style' => 'document/literal',
                    'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
                    'schema_complete' => true, 'input' => empty_msg, 'output' => empty_msg
                  }
                }
              }
            }
          }
        }
      }

      restored = described_class.from_h(compact_hash)
      ops = restored.operations

      expect(ops.first[:style]).to eq('document/literal')
      expect(ops.first[:soap_action]).to eq('urn:op1')
    end
  end

  describe 'round-trip with defaults' do
    it 'to_h round-trips through from_h' do
      original = WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock)
      restored = described_class.from_h(original.to_h)

      expect(restored.to_h).to eq(original.to_h)
    end

    it 'JSON round-trips preserve defaults structure' do
      original = WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock)
      original_json = original.to_json
      json_hash = JSON.parse(original_json)

      # Verify the serialized form has defaults
      port = json_hash.dig('services', 'AuthenticationWebServiceImplService',
        'ports', 'AuthenticationWebServiceImplPort')
      expect(port).to have_key('defaults')

      restored = described_class.from_h(json_hash)
      expect(JSON.parse(restored.to_json)).to eq(JSON.parse(original_json))
    end

    it 'preserves read paths after round-trip' do
      original = WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock)
      restored = described_class.from_h(original.to_h)

      expect(restored.input('authenticate')).to eq(original.input('authenticate'))
      expect(restored.output('authenticate')).to eq(original.output('authenticate'))
      expect(restored.operations).to eq(original.operations)
    end
  end

  describe 'overloaded operations' do
    subject(:definition) do
      described_class.new(
        'schema_version' => WSDL::Definition::Builder::SCHEMA_VERSION,
        'service_name' => 'Svc', 'fingerprint' => 'sha256:test', 'sources' => [],
        'namespaces' => ['http://schemas.xmlsoap.org/wsdl/soap/'],
        'services' => {
          'Svc' => {
            'ports' => {
              'Port' => {
                'type' => 0, 'endpoint' => 'http://x',
                'operations' => {
                  'Lookup' => [
                    op_base.merge('name' => 'Lookup', 'input_name' => 'ById'),
                    op_base.merge('name' => 'Lookup', 'input_name' => 'ByName')
                  ]
                }
              }
            }
          }
        }
      )
    end

    let(:op_base) do
      {
        'soap_action' => nil, 'soap_version' => '1.1', 'input_style' => 'document/literal',
        'output_style' => 'document/literal', 'rpc_input_namespace' => nil,
        'rpc_output_namespace' => nil, 'schema_complete' => true,
        'input' => { 'header' => [], 'body' => [] }, 'output' => { 'header' => [], 'body' => [] }
      }
    end

    it 'lists overloaded operations with input_name' do
      ops = definition.operations
      expect(ops.size).to eq(2)
      expect(ops).to all(include(:input_name))
      expect(ops.map { |o| o[:input_name] }).to contain_exactly('ById', 'ByName')
    end

    it 'disambiguates with input_name' do
      data = definition.operation_data('Svc', 'Port', 'Lookup', input_name: 'ById')
      expect(data['input_name']).to eq('ById')
    end

    it 'raises without input_name for overloaded operations' do
      expect {
        definition.operation_data('Svc', 'Port', 'Lookup')
      }.to raise_error(ArgumentError, /overloaded/)
    end

    it 'raises with wrong input_name' do
      expect {
        definition.operation_data('Svc', 'Port', 'Lookup', input_name: 'ByAge')
      }.to raise_error(ArgumentError, /No overload.*ByAge/)
    end
  end

  private

  def collect_all_types(elements)
    elements.flat_map do |el|
      [el[:type]] + collect_all_types(el[:children] || [])
    end
  end

  def collect_all_keys(elements)
    elements.flat_map { |el|
      el.keys + collect_all_keys(el[:children] || [])
    }.uniq
  end

  def flatten_elements(elements)
    elements.flat_map do |el|
      [el] + flatten_elements(el[:children] || [])
    end
  end

  def simple_element(name, xsd_type: 'xsd:string')
    {
      'name' => name, 'ns' => nil, 'type' => 'simple', 'xsd_type' => xsd_type
    }
  end
end
