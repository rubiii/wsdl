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

    expect(operation.contract.request.body.paths).to eq([
      { path: ['getStTables'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[getStTables username],
        kind: :simple,
        namespace: namespace,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[getStTables password],
        kind: :simple,
        namespace: namespace,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[getStTables version],
        kind: :simple,
        namespace: namespace,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
}
    ])
  end
end
