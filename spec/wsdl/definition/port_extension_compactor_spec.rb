# frozen_string_literal: true

RSpec.describe WSDL::Definition::PortExtensionCompactor do
  let(:empty_msg) { { 'header' => [], 'body' => [] } }

  let(:op_a) do
    {
      'name' => 'OpA', 'input_name' => nil,
      'soap_action' => 'urn:opA', 'input' => empty_msg, 'output' => empty_msg
    }
  end

  let(:op_b) do
    {
      'name' => 'OpB', 'input_name' => nil,
      'soap_action' => 'urn:opB', 'input' => empty_msg, 'output' => empty_msg
    }
  end

  let(:op_c) do
    {
      'name' => 'OpC', 'input_name' => nil,
      'soap_action' => 'urn:opC', 'input' => empty_msg, 'output' => empty_msg
    }
  end

  def build_services(ports_hash, service_name: 'Svc')
    {
      service_name => {
        'ports' => ports_hash
      }
    }
  end

  def build_port(endpoint:, operations:, type: 0, defaults: nil)
    h = { 'type' => type, 'endpoint' => endpoint, 'operations' => operations }
    h['defaults'] = defaults if defaults
    h
  end

  describe '.call' do
    it 'replaces the second port with an extends reference when operations are identical' do
      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', operations: { 'OpA' => op_a }),
        'PortB' => build_port(endpoint: 'http://b', operations: { 'OpA' => op_a })
      })

      result = described_class.call(services)
      port_a = result.dig('Svc', 'ports', 'PortA')
      port_b = result.dig('Svc', 'ports', 'PortB')

      expect(port_a).to have_key('operations')
      expect(port_a).not_to have_key('extends')

      expect(port_b).to have_key('extends')
      expect(port_b['extends']).to eq('PortA')
      expect(port_b).not_to have_key('operations')
    end

    it 'does not add extends when operations differ' do
      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', operations: { 'OpA' => op_a }),
        'PortB' => build_port(endpoint: 'http://b', operations: { 'OpB' => op_b })
      })

      result = described_class.call(services)
      port_a = result.dig('Svc', 'ports', 'PortA')
      port_b = result.dig('Svc', 'ports', 'PortB')

      expect(port_a).to have_key('operations')
      expect(port_a).not_to have_key('extends')

      expect(port_b).to have_key('operations')
      expect(port_b).not_to have_key('extends')
    end

    it 'extends only the matching port when three ports have mixed operations' do
      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', operations: { 'OpA' => op_a }),
        'PortB' => build_port(endpoint: 'http://b', operations: { 'OpA' => op_a }),
        'PortC' => build_port(endpoint: 'http://c', operations: { 'OpC' => op_c })
      })

      result = described_class.call(services)

      expect(result.dig('Svc', 'ports', 'PortA')).to have_key('operations')
      expect(result.dig('Svc', 'ports', 'PortA')).not_to have_key('extends')

      expect(result.dig('Svc', 'ports', 'PortB', 'extends')).to eq('PortA')
      expect(result.dig('Svc', 'ports', 'PortB')).not_to have_key('operations')

      expect(result.dig('Svc', 'ports', 'PortC')).to have_key('operations')
      expect(result.dig('Svc', 'ports', 'PortC')).not_to have_key('extends')
    end

    it 'does not add extends when there is only a single port' do
      services = build_services({
        'Solo' => build_port(endpoint: 'http://solo', operations: { 'OpA' => op_a })
      })

      result = described_class.call(services)
      solo = result.dig('Svc', 'ports', 'Solo')

      expect(solo).to have_key('operations')
      expect(solo).not_to have_key('extends')
    end

    it 'preserves endpoint, type, and defaults on the extended port' do
      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', type: 0, operations: { 'OpA' => op_a },
          defaults: { 'soap_version' => '1.1' }),
        'PortB' => build_port(endpoint: 'http://b', type: 1, operations: { 'OpA' => op_a },
          defaults: { 'soap_version' => '1.2' })
      })

      result = described_class.call(services)
      port_b = result.dig('Svc', 'ports', 'PortB')

      expect(port_b['extends']).to eq('PortA')
      expect(port_b['endpoint']).to eq('http://b')
      expect(port_b['type']).to eq(1)
      expect(port_b['defaults']).to eq('soap_version' => '1.2')
    end

    it 'extends ports with identical overloaded operations' do
      overloaded_ops = {
        'Lookup' => [
          op_a.merge('name' => 'Lookup', 'input_name' => 'ById'),
          op_a.merge('name' => 'Lookup', 'input_name' => 'ByName')
        ]
      }

      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', operations: overloaded_ops),
        'PortB' => build_port(endpoint: 'http://b', operations: overloaded_ops)
      })

      result = described_class.call(services)

      expect(result.dig('Svc', 'ports', 'PortA')).to have_key('operations')
      expect(result.dig('Svc', 'ports', 'PortB', 'extends')).to eq('PortA')
      expect(result.dig('Svc', 'ports', 'PortB')).not_to have_key('operations')
    end

    it 'returns a fully frozen structure' do
      services = build_services({
        'PortA' => build_port(endpoint: 'http://a', operations: { 'OpA' => op_a }),
        'PortB' => build_port(endpoint: 'http://b', operations: { 'OpA' => op_a })
      })

      result = described_class.call(services)

      expect(result).to be_frozen
      expect(result['Svc']).to be_frozen
      expect(result.dig('Svc', 'ports')).to be_frozen
      expect(result.dig('Svc', 'ports', 'PortA')).to be_frozen
      expect(result.dig('Svc', 'ports', 'PortA', 'operations')).to be_frozen
      expect(result.dig('Svc', 'ports', 'PortB')).to be_frozen
    end

    it 'does not extend across different services' do
      services = build_services(
        { 'PortA' => build_port(endpoint: 'http://a', operations: { 'OpA' => op_a }) },
        service_name: 'Svc1'
      ).merge(
        build_services(
          { 'PortX' => build_port(endpoint: 'http://x', operations: { 'OpA' => op_a }) },
          service_name: 'Svc2'
        )
      )

      result = described_class.call(services)

      expect(result.dig('Svc1', 'ports', 'PortA')).to have_key('operations')
      expect(result.dig('Svc1', 'ports', 'PortA')).not_to have_key('extends')

      expect(result.dig('Svc2', 'ports', 'PortX')).to have_key('operations')
      expect(result.dig('Svc2', 'ports', 'PortX')).not_to have_key('extends')
    end
  end
end
