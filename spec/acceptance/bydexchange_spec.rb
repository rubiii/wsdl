# frozen_string_literal: true

RSpec.describe 'BYDExchange' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/bydexchange/manifest'), http_mock) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'BYDExchangeServer' => {
        ports: {
          'BasicHttpBinding_IBYDExchangeServer' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://bydexchange.nbs-us.com/BYDExchangeServer.svc'
          }
        }
      }
    )
  end

  it 'resolves WSDL imports to get the operations' do
    operations = client.operations('BYDExchangeServer', 'BasicHttpBinding_IBYDExchangeServer')
    expect(operations).to include('GetCustomer')
  end
end
