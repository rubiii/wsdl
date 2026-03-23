# frozen_string_literal: true

RSpec.describe WSDL::Operation do
  # namespace reference:
  #   http://www.ibm.com/developerworks/webservices/library/ws-tip-namespace/index.html
  context 'with a document/literal wrapped document' do
    it 'works for op1' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op1 = client.operation('SampleService', 'Sample', 'op1')
      expect(op1.input_style).to eq('document/literal')

      expect(op1.contract.request.body.paths).to eq([
        { path: ['op1'],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op1 in],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op1 in data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
},
        { path: %w[op1 in data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
}
      ])
    end

    it 'works for op2' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op2 = client.operation('SampleService', 'Sample', 'op2')
      expect(op2.input_style).to eq('document/literal')

      expect(op2.contract.request.body.paths).to eq([
        { path: ['op2'],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op2 in],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op2 in data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
},
        { path: %w[op2 in data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
}
      ])
    end

    it 'works for op3' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op3 = client.operation('SampleService', 'Sample', 'op3')
      expect(op3.input_style).to eq('document/literal')

      expect(op3.contract.request.body.paths).to eq([
        { path: ['op3'],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op3 DataElem],
          kind: :complex,
          namespace: 'http://dataNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op3 DataElem data1],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
},
        { path: %w[op3 DataElem data2],
          kind: :simple,
          namespace: 'http://dataNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
},
        { path: %w[op3 in2],
          kind: :complex,
          namespace: 'http://apiNamespace.com',
          form: 'unqualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          wildcard: false
},
        { path: %w[op3 in2 RefDataElem],
          kind: :simple,
          namespace: 'http://refNamespace.com',
          form: 'qualified',
          singular: true,
          min_occurs: '1',
          max_occurs: '1',
          type: 'int',
          list: false
}
      ])
    end
  end
end
