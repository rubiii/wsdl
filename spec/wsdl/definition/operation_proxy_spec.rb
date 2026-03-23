# frozen_string_literal: true

RSpec.describe WSDL::Definition::OperationProxy do
  subject(:proxy) { described_class.new(operation_data, endpoint: 'http://example.com/service') }

  let(:element_hash) do
    {
      name: 'user', namespace: 'http://example.com', form: 'qualified',
      type: :complex, xsd_type: nil, min_occurs: 1, max_occurs: 1,
      nillable: false, singular: true, list: false, any_content: false,
      recursive_type: nil, complex_type_id: nil, children: [], attributes: []
    }
  end

  let(:operation_data) do
    {
      name: 'GetUser',
      soap_action: 'http://example.com/GetUser',
      soap_version: '1.1',
      input_style: 'document/literal',
      output_style: 'document/literal',
      rpc_input_namespace: nil,
      rpc_output_namespace: nil,
      input: { header: [], body: [element_hash] },
      output: { header: [], body: [element_hash] }
    }
  end

  describe 'scalar accessors' do
    it 'returns name' do
      expect(proxy.name).to eq('GetUser')
    end

    it 'returns endpoint' do
      expect(proxy.endpoint).to eq('http://example.com/service')
    end

    it 'returns soap_action' do
      expect(proxy.soap_action).to eq('http://example.com/GetUser')
    end

    it 'returns soap_version' do
      expect(proxy.soap_version).to eq('1.1')
    end

    it 'returns input_style' do
      expect(proxy.input_style).to eq('document/literal')
    end

    it 'returns output_style' do
      expect(proxy.output_style).to eq('document/literal')
    end
  end

  describe '#input' do
    it 'returns a MessageProxy' do
      expect(proxy.input).to be_a(WSDL::Definition::MessageProxy)
    end

    it 'provides body_parts as ElementHash arrays' do
      expect(proxy.input.body_parts).to all(be_a(WSDL::Definition::ElementHash))
      expect(proxy.input.body_parts.first.name).to eq('user')
    end

    it 'provides header_parts as ElementHash arrays' do
      expect(proxy.input.header_parts).to eq([])
    end

    it 'memoizes the result' do
      expect(proxy.input).to equal(proxy.input)
    end
  end

  describe '#output' do
    it 'returns a MessageProxy' do
      expect(proxy.output).to be_a(WSDL::Definition::MessageProxy)
    end

    it 'provides body_parts' do
      expect(proxy.output.body_parts.first.name).to eq('user')
    end

    it 'returns nil for one-way operations' do
      one_way_data = operation_data.merge(output: nil)
      one_way = described_class.new(one_way_data, endpoint: 'http://example.com/service')

      expect(one_way.output).to be_nil
    end

    it 'memoizes the result' do
      expect(proxy.output).to equal(proxy.output)
    end

    it 'memoizes nil for one-way operations' do
      one_way_data = operation_data.merge(output: nil)
      one_way = described_class.new(one_way_data, endpoint: 'http://example.com/service')

      one_way.output
      expect(one_way.output).to be_nil
    end
  end

  describe '#binding_operation' do
    it 'returns a BindingProxy' do
      expect(proxy.binding_operation).to be_a(WSDL::Definition::BindingProxy)
    end

    it 'provides input_body with namespace' do
      expect(proxy.binding_operation.input_body).to eq({ namespace: nil })
    end

    it 'provides output_body with namespace' do
      expect(proxy.binding_operation.output_body).to eq({ namespace: nil })
    end

    context 'with RPC namespaces' do
      let(:operation_data) do
        super().merge(
          input_style: 'rpc/literal',
          rpc_input_namespace: 'http://example.com/rpc',
          rpc_output_namespace: 'http://example.com/rpc'
        )
      end

      it 'returns input namespace' do
        expect(proxy.binding_operation.input_body[:namespace]).to eq('http://example.com/rpc')
      end

      it 'returns output namespace' do
        expect(proxy.binding_operation.output_body[:namespace]).to eq('http://example.com/rpc')
      end
    end
  end

  describe 'duck-type compatibility with Parser::OperationInfo' do
    it 'responds to all methods that Operation calls' do
      methods = %i[
        name endpoint soap_action soap_version input_style output_style
        input output binding_operation
      ]
      methods.each do |method|
        expect(proxy).to respond_to(method), "Expected OperationProxy to respond to #{method}"
      end
    end

    it 'responds to all methods that OperationContract calls' do
      %i[input output input_style].each do |method|
        expect(proxy).to respond_to(method), "Expected OperationProxy to respond to #{method}"
      end
    end
  end

  describe WSDL::Definition::MessageProxy do
    subject(:message) { described_class.new(header: [element_hash], body: [element_hash]) }

    it 'wraps header_parts as frozen ElementHash arrays' do
      expect(message.header_parts).to all(be_a(WSDL::Definition::ElementHash))
      expect(message.header_parts).to be_frozen
    end

    it 'wraps body_parts as frozen ElementHash arrays' do
      expect(message.body_parts).to all(be_a(WSDL::Definition::ElementHash))
      expect(message.body_parts).to be_frozen
    end

    it 'memoizes header_parts' do
      expect(message.header_parts).to equal(message.header_parts)
    end

    it 'memoizes body_parts' do
      expect(message.body_parts).to equal(message.body_parts)
    end
  end
end
