# frozen_string_literal: true

RSpec.describe WSDL::Definition::NamespaceCompactor do
  def build_services(port_type:, elements:, rpc_input_ns: nil, rpc_output_ns: nil)
    {
      'Svc' => { 'ports' => { 'Port' => {
        'type' => port_type, 'endpoint' => 'http://x',
        'operations' => { 'Op' => {
          'name' => 'Op', 'input_name' => nil,
          'soap_action' => nil, 'soap_version' => '1.1',
          'input_style' => 'document/literal', 'output_style' => nil,
          'rpc_input_namespace' => rpc_input_ns, 'rpc_output_namespace' => rpc_output_ns,
          'schema_complete' => true,
          'input' => { 'header' => [], 'body' => elements },
          'output' => nil
        }
}
      }
}
}
    }
  end

  it 'collects unique namespace URIs in first-occurrence order' do
    elements = [
      { 'name' => 'a', 'ns' => 'http://second.com', 'type' => 'simple', 'xsd_type' => 'xsd:string' },
      { 'name' => 'b', 'ns' => 'http://first.com', 'type' => 'simple', 'xsd_type' => 'xsd:int' }
    ]
    services = build_services(port_type: 'http://first.com', elements:)

    namespaces, _compacted = described_class.call(services)

    expect(namespaces).to eq(['http://first.com', 'http://second.com'])
  end

  it 'replaces element namespace URIs with integer indices' do
    elements = [{ 'name' => 'x', 'ns' => 'http://example.com', 'type' => 'simple', 'xsd_type' => 'xsd:string' }]
    services = build_services(port_type: 'http://soap/', elements:)

    namespaces, compacted = described_class.call(services)
    element = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op', 'input', 'body', 0)

    expect(element['ns']).to eq(namespaces.index('http://example.com'))
  end

  it 'replaces port type URIs with integer indices' do
    services = build_services(port_type: 'http://soap/', elements: [])

    namespaces, compacted = described_class.call(services)
    port_type = compacted.dig('Svc', 'ports', 'Port', 'type')

    expect(port_type).to be_an(Integer)
    expect(namespaces[port_type]).to eq('http://soap/')
  end

  it 'replaces RPC namespace URIs with integer indices' do
    services = build_services(
      port_type: 'http://soap/', elements: [],
      rpc_input_ns: 'http://rpc.example.com', rpc_output_ns: 'http://rpc.example.com'
    )

    namespaces, compacted = described_class.call(services)
    operation = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op')

    expect(operation['rpc_input_namespace']).to be_an(Integer)
    expect(namespaces[operation['rpc_input_namespace']]).to eq('http://rpc.example.com')
    expect(operation['rpc_output_namespace']).to eq(operation['rpc_input_namespace'])
  end

  it 'preserves null namespace values' do
    elements = [{ 'name' => 'x', 'ns' => nil, 'type' => 'simple', 'xsd_type' => 'xsd:string' }]
    services = build_services(port_type: 'http://soap/', elements:)

    _namespaces, compacted = described_class.call(services)
    element = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op', 'input', 'body', 0)

    expect(element['ns']).to be_nil
  end

  it 'compacts namespace URIs in nested children' do
    child = { 'name' => 'child', 'ns' => 'http://example.com', 'type' => 'simple', 'xsd_type' => 'xsd:int' }
    elements = [{
      'name' => 'parent', 'ns' => 'http://example.com', 'type' => 'complex',
      'children' => [child]
    }
]
    services = build_services(port_type: 'http://soap/', elements:)

    namespaces, compacted = described_class.call(services)
    parent = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op', 'input', 'body', 0)
    compacted_child = parent['children'].first

    expect(compacted_child['ns']).to be_an(Integer)
    expect(namespaces[compacted_child['ns']]).to eq('http://example.com')
  end

  it 'deduplicates namespace URIs across elements and ports' do
    elements = [
      { 'name' => 'a', 'ns' => 'http://example.com', 'type' => 'simple', 'xsd_type' => 'xsd:string' },
      { 'name' => 'b', 'ns' => 'http://example.com', 'type' => 'simple', 'xsd_type' => 'xsd:int' }
    ]
    services = build_services(port_type: 'http://example.com', elements:)

    namespaces, _compacted = described_class.call(services)

    expect(namespaces).to eq(['http://example.com'])
  end

  it 'handles overloaded operations' do
    services = {
      'Svc' => { 'ports' => { 'Port' => {
        'type' => 'http://soap/', 'endpoint' => 'http://x',
        'operations' => { 'Op' => [
          {
            'name' => 'Op', 'input_name' => 'A',
            'soap_action' => nil, 'soap_version' => '1.1',
            'input_style' => nil, 'output_style' => nil,
            'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
            'schema_complete' => true,
            'input' => { 'header' => [], 'body' => [
              { 'name' => 'x', 'ns' => 'http://a.com', 'type' => 'simple', 'xsd_type' => 'xsd:string' }
            ]
},
            'output' => nil
          },
          {
            'name' => 'Op', 'input_name' => 'B',
            'soap_action' => nil, 'soap_version' => '1.1',
            'input_style' => nil, 'output_style' => nil,
            'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
            'schema_complete' => true,
            'input' => { 'header' => [], 'body' => [
              { 'name' => 'y', 'ns' => 'http://b.com', 'type' => 'simple', 'xsd_type' => 'xsd:int' }
            ]
},
            'output' => nil
          }
        ]
}
      }
}
}
    }

    namespaces, compacted = described_class.call(services)
    ops = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op')

    expect(namespaces).to include('http://a.com', 'http://b.com')
    expect(ops).to be_an(Array)
    expect(ops[0].dig('input', 'body', 0, 'ns')).to be_an(Integer)
    expect(ops[1].dig('input', 'body', 0, 'ns')).to be_an(Integer)
  end
end
