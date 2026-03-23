# frozen_string_literal: true

RSpec.describe 'TeamSoftware' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/team_software/manifest'), http_mock) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'ServiceManager' => {
        ports: {
          'BasicHttpBinding_IWinTeamServiceManager' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://winteamservicestest.myteamsoftware.com/Services.svc'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'ServiceManager'
    port = 'BasicHttpBinding_IWinTeamServiceManager'
    operation = client.operation(service, port, 'Login')

    expect(operation.soap_action).to eq('http://tempuri.org/IWinTeamServiceManager/Login')
    expect(operation.endpoint).to eq('https://winteamservicestest.myteamsoftware.com/Services.svc')

    namespace = 'http://tempuri.org/'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Login'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Login MappingKey],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
}
    ])
  end
end
