# frozen_string_literal: true

RSpec.describe 'Authentication service' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/authentication')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AuthenticationWebServiceImplService' => {
        ports: {
          'AuthenticationWebServiceImplPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://example.com/validation/1.0/AuthenticationService',
            operations: [{ name: 'authenticate' }]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'AuthenticationWebServiceImplService'
    port = 'AuthenticationWebServiceImplPort'

    operation = client.operation(service, port, 'authenticate')

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('http://example.com/validation/1.0/AuthenticationService')

    namespace = 'http://v1_0.ws.auth.order.example.com/'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['authenticate'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false },
      { path: %w[authenticate user],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false },
      { path: %w[authenticate password],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false }
    ])
  end
end
