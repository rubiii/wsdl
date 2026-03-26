# frozen_string_literal: true

RSpec.describe 'Juniper' do
  subject(:client) do
    WSDL::Client.new WSDL.parse(fixture('wsdl/juniper'), strictness:),
      strictness:
  end

  let(:strictness) do
    {
      schema_imports: false,
      schema_references: false,
      request_validation: false
    }
  end

  it 'skips the relative schema import to still show other information' do
    expect(client.services).to eq(
      'SystemService' => {
        ports: {
          'System' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://10.1.1.1:8443/axis2/services/SystemService',
            operations: [
              { name: 'LoginRequest' },
              { name: 'RespondToChallengeRequest' },
              { name: 'LogoutRequest' },
              { name: 'GetSystemInfoRequest' }
            ]
          }
        }
      }
    )
  end

  it 'allows request DSL usage in relaxed mode for operations with unresolved imported types' do
    operation = client.operation('SystemService', 'System', 'LoginRequest')

    expect {
      operation.prepare do
        tag('LoginRequest') do
          tag('username', 'john')
        end
      end
    }.not_to raise_error

    expect { operation.to_xml }.not_to raise_error
  end
end
