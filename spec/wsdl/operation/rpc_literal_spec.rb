# frozen_string_literal: true

RSpec.describe WSDL::Operation do
  # namespace reference:
  #   http://www.ibm.com/developerworks/webservices/library/ws-tip-namespace/index.html
  context 'with an rpc/literal document' do
    it 'qualifies the RPC wrapper with the soap:body namespace' do
      client = WSDL::Client.new WSDL.parse(fixture('wsdl/rpc_literal'))

      op1 = client.operation('SampleService', 'Sample', 'op1')
      expect(op1.input_style).to eq('rpc/literal')

      expect(op1.contract.request.body.paths).to eq([
        { path: ['in'],
          kind: :complex,
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false },
        { path: %w[in data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false },
        { path: %w[in data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false }
      ])
    end

    it 'qualifies the RPC wrapper with the soap:body namespace (which differs from the tns)' do
      client = WSDL::Client.new WSDL.parse(fixture('wsdl/rpc_literal'))

      op2 = client.operation('SampleService', 'Sample', 'op2')
      expect(op2.input_style).to eq('rpc/literal')

      expect(op2.contract.request.body.paths).to eq([
        { path: ['in'],
          kind: :complex,
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false },
        { path: %w[in data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false },
        { path: %w[in data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false }
      ])
    end

    it 'does not qualify the RPC wrapper without a soap:body namespace and follows element refs' do
      client = WSDL::Client.new WSDL.parse(fixture('wsdl/rpc_literal'))

      op3 = client.operation('SampleService', 'Sample', 'op3')
      expect(op3.input_style).to eq('rpc/literal')

      expect(op3.contract.request.body.paths).to eq([
        { path: ['DataElem'],
          kind: :complex,
          namespace: 'http://dataNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false },
        { path: %w[DataElem data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false },
        { path: %w[DataElem data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false },
        { path: ['in2'],
          kind: :complex,
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false },
        { path: %w[in2 RefDataElem],
          kind: :simple,
          namespace: 'http://refNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false }
      ])
    end
  end
end
