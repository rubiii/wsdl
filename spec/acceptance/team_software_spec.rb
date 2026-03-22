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

    expect(request_body_paths(operation)).to eq([
      [['Login'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Login MappingKey],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
}
]
    ])
  end
end
