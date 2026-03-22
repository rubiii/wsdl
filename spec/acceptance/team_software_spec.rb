# frozen_string_literal: true

RSpec.describe 'TeamSoftware' do
  subject(:client) { WSDL::Client.new(wsdl_url, http: http_mock) }

  let(:wsdl_url) { 'http://bydexchange.nbs-us.com/BYDExchangeServer.svc?wsdl' }

  before do
    http_mock.fake_request(wsdl_url, 'wsdl/team_software/team_software.wsdl')

    # 4 schemas to import.
    #
    # XXX: actually some of the imported schemas import some of the other schemas,
    #      but it seems like we're not following those?!
    schema_import_base = 'https://winteamservicestest.myteamsoftware.com/Services.svc?xsd=xsd%d'
    (0..3).each do |i|
      url = schema_import_base % i
      http_mock.fake_request(url, "wsdl/team_software/team_software#{i}.xsd")
    end
  end

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
