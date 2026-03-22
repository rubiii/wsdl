# frozen_string_literal: true

RSpec.describe 'Wasmuth' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/wasmuth/manifest'), http_mock) }

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
