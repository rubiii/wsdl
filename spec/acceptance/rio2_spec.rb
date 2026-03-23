# frozen_string_literal: true

RSpec.describe 'Rio II' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/rio2/manifest'), http_mock) }

  it 'only downloads WSDL and XML Schema imports once per location' do
    expect(client.services).to eq(
      'SecurityService' => {
        ports: {
          'BasicHttpBinding_ISecurityService' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://193.155.1.72/MyCentral-RioII-Services/SecurityService.svc/soap',
            operations: [
              { name: 'StartSession' },
              { name: 'EndSession' },
              { name: 'GetSessionState' },
              { name: 'GetSessionFromToken' }
            ]
          }
        }
      }
    )
  end

  it 'knows the GetSessionState operation' do
    service = :SecurityService
    port = :BasicHttpBinding_ISecurityService
    operation = client.operation(service, port, :GetSessionState)

    expect(operation.input_style).to eq('document/literal')

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      GetSessionState: {
        session: {
          ApplicationId: 'string',
          CultureCode: 'string',
          SessionId: 'string'
        },
        request: {
          Context: 'string'
        }
      }
    )
  end
end
