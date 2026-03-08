# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Integration with Wasmuth' do
  subject(:client) { WSDL::Client.new(wsdl_url, http: http_mock) }

  let(:wsdl_url) { 'http://www3.mediaservice-wasmuth.de/online-ws-2.0/OnlineSync?wsdl' }

  before do
    http_mock.fake_request(wsdl_url, 'wsdl/wasmuth/wasmuth.wsdl')

    # 2 schemas to import.
    schema_import_base = 'http://www3.mediaservice-wasmuth.de:80/online-ws-2.0/OnlineSync?xsd=%d'
    http_mock.fake_request(schema_import_base % 1, 'wsdl/wasmuth/wasmuth1.xsd')
    http_mock.fake_request(schema_import_base % 2, 'wsdl/wasmuth/wasmuth2.xsd')
  end

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'OnlineSyncService' => {
        ports: {
          'OnlineSyncPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://www3.mediaservice-wasmuth.de:80/online-ws-2.0/OnlineSync'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation('OnlineSyncService', 'OnlineSyncPort', 'getStTables')

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('http://www3.mediaservice-wasmuth.de:80/online-ws-2.0/OnlineSync')

    namespace = 'http://ws.online.msw/'

    expect(request_body_paths(operation)).to eq([
      [['getStTables'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[getStTables username],
       { namespace: namespace, form: 'unqualified', singular: true,
         type: 'xs:string'
}
],
      [%w[getStTables password],
       { namespace: namespace, form: 'unqualified', singular: true,
         type: 'xs:string'
}
],
      [%w[getStTables version],
       { namespace: namespace, form: 'unqualified', singular: true,
         type: 'xs:string'
}
]
    ])
  end
end
