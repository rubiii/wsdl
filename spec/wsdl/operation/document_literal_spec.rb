# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Operation do
  # namespace reference:
  #   http://www.ibm.com/developerworks/webservices/library/ws-tip-namespace/index.html
  context 'with a document/literal wrapped document' do
    it 'works for op1' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op1 = client.operation('SampleService', 'Sample', 'op1')
      expect(op1.input_style).to eq('document/literal')

      expect(request_body_paths(op1)).to eq([
        [['op1'],
         { namespace: 'http://apiNamespace.com', form: 'qualified', singular: true }
],
        [%w[op1 in],
         { namespace: 'http://apiNamespace.com', form: 'unqualified', singular: true }
],
        [%w[op1 in data1],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
],
        [%w[op1 in data2],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
]
      ])
    end

    it 'works for op2' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op2 = client.operation('SampleService', 'Sample', 'op2')
      expect(op2.input_style).to eq('document/literal')

      expect(request_body_paths(op2)).to eq([
        [['op2'],
         { namespace: 'http://apiNamespace.com', form: 'qualified', singular: true }
],
        [%w[op2 in],
         { namespace: 'http://apiNamespace.com', form: 'unqualified', singular: true }
],
        [%w[op2 in data1],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
],
        [%w[op2 in data2],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
]
      ])
    end

    it 'works for op3' do
      client = WSDL::Client.new fixture('wsdl/document_literal_wrapped')

      op3 = client.operation('SampleService', 'Sample', 'op3')
      expect(op3.input_style).to eq('document/literal')

      expect(request_body_paths(op3)).to eq([
        [['op3'],
         { namespace: 'http://apiNamespace.com', form: 'qualified', singular: true }
],
        [%w[op3 DataElem],
         { namespace: 'http://dataNamespace.com', form: 'qualified',   singular: true }
],
        [%w[op3 DataElem data1],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
],
        [%w[op3 DataElem data2],
         { namespace: 'http://dataNamespace.com', form: 'unqualified', singular: true,
           type: 'int'
}
],
        [%w[op3 in2],
         { namespace: 'http://apiNamespace.com',  form: 'unqualified', singular: true }
],
        [%w[op3 in2 RefDataElem],
         { namespace: 'http://refNamespace.com',  form: 'qualified',   singular: true,
           type: 'int'
}
]
      ])
    end
  end
end
