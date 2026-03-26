# frozen_string_literal: true

RSpec.describe 'Namespaced actions example' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/namespaced_actions')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'api' => {
        ports: {
          'apiSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.example.com/api/api.asmx',
            operations: [
              { name: 'GetApiKey' },
              { name: 'DeleteClient' },
              { name: 'GetClients' }
            ]
          },
          'apiSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'https://api.example.com/api/api.asmx',
            operations: [
              { name: 'GetApiKey' },
              { name: 'DeleteClient' },
              { name: 'GetClients' }
            ]
          }
        }
      }
    )
  end

  it 'works fine with dot-namespaced operations' do
    operation = client.operation('api', 'apiSoap', 'DeleteClient')

    expect(operation.soap_action).to eq('http://api.example.com/api/Client.Delete')
    expect(operation.endpoint).to eq('https://api.example.com/api/api.asmx')

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Client.Delete'],
        kind: :complex,
        namespace: 'http://api.example.com/api/',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Client.Delete ApiKey],
        kind: :simple,
        namespace: 'http://api.example.com/api/',
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[Client.Delete ClientID],
        kind: :simple,
        namespace: 'http://api.example.com/api/',
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
}
    ])
  end
end
