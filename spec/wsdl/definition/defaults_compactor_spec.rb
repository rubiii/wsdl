# frozen_string_literal: true

RSpec.describe WSDL::Definition::DefaultsCompactor do
  let(:empty_msg) { { 'header' => [], 'body' => [] } }

  let(:op_base) do
    {
      'soap_action' => nil, 'soap_version' => '1.1', 'input_style' => 'document/literal',
      'output_style' => 'document/literal', 'rpc_input_namespace' => nil,
      'rpc_output_namespace' => nil, 'schema_complete' => true,
      'input' => empty_msg, 'output' => empty_msg
    }
  end

  # Builds a minimal services hash (post-type-compaction).
  # Accepts an operations hash for a single port.
  def build_services(operations)
    {
      'Svc' => {
        'ports' => {
          'Port' => {
            'type' => 0, 'endpoint' => 'http://x',
            'operations' => operations
          }
        }
      }
    }
  end

  def dig_port(services)
    services.dig('Svc', 'ports', 'Port')
  end

  describe '.call' do
    it 'extracts uniform fields into port defaults' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => nil),
        'Op2' => op_base.merge('name' => 'Op2', 'input_name' => nil)
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port).to have_key('defaults')
      expect(port['defaults']).to include('soap_version' => '1.1', 'input_style' => 'document/literal')

      port['operations'].each_value do |op|
        expect(op).not_to have_key('soap_version')
        expect(op).not_to have_key('input_style')
      end
    end

    it 'does not extract non-uniform fields' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => nil, 'soap_version' => '1.1'),
        'Op2' => op_base.merge('name' => 'Op2', 'input_name' => nil, 'soap_version' => '1.2')
      )

      result = described_class.call(services)
      port = dig_port(result)

      port['operations'].each_value do |op|
        expect(op).to have_key('soap_version')
      end

      expect(port).to have_key('defaults')
      expect(port['defaults']).not_to have_key('soap_version')
    end

    it 'never extracts excluded fields even when uniform' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => 'Same', 'soap_action' => 'urn:same'),
        'Op2' => op_base.merge('name' => 'Op2', 'input_name' => 'Same', 'soap_action' => 'urn:same')
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port).to have_key('defaults')
      %w[name input_name soap_action input output].each do |excluded|
        expect(port['defaults']).not_to have_key(excluded)
      end
    end

    it 'extracts defaults from a single-operation port' do
      services = build_services(
        'Solo' => op_base.merge('name' => 'Solo', 'input_name' => nil)
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port).to have_key('defaults')
      expect(port['defaults']).to include('soap_version' => '1.1')
    end

    it 'omits defaults for a port with zero operations' do
      services = build_services({})

      result = described_class.call(services)
      port = dig_port(result)

      expect(port).not_to have_key('defaults')
    end

    it 'extracts defaults from overloaded operations' do
      services = build_services(
        'Lookup' => [
          op_base.merge('name' => 'Lookup', 'input_name' => 'ById'),
          op_base.merge('name' => 'Lookup', 'input_name' => 'ByName')
        ]
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port).to have_key('defaults')
      expect(port['defaults']).to include('soap_version' => '1.1')

      port['operations']['Lookup'].each do |overload|
        expect(overload).not_to have_key('soap_version')
        expect(overload).not_to have_key('input_style')
      end
    end

    it 'treats uniform nil values as valid defaults' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => nil, 'rpc_input_namespace' => nil),
        'Op2' => op_base.merge('name' => 'Op2', 'input_name' => nil, 'rpc_input_namespace' => nil)
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port['defaults']).to have_key('rpc_input_namespace')
      expect(port['defaults']['rpc_input_namespace']).to be_nil
    end

    it 'handles partial uniformity' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => nil,
          'soap_version' => '1.1', 'output_style' => 'document/literal'),
        'Op2' => op_base.merge('name' => 'Op2', 'input_name' => nil,
          'soap_version' => '1.1', 'output_style' => 'rpc/literal')
      )

      result = described_class.call(services)
      port = dig_port(result)

      expect(port['defaults']).to include('soap_version' => '1.1')
      expect(port['defaults']).not_to have_key('output_style')

      port['operations'].each_value do |op|
        expect(op).not_to have_key('soap_version')
        expect(op).to have_key('output_style')
      end
    end

    it 'returns a frozen structure' do
      services = build_services(
        'Op1' => op_base.merge('name' => 'Op1', 'input_name' => nil)
      )

      result = described_class.call(services)

      expect(result).to be_frozen
      expect(dig_port(result)).to be_frozen
      expect(dig_port(result)['defaults']).to be_frozen
      expect(dig_port(result)['operations']).to be_frozen
    end
  end
end
