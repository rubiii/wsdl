# frozen_string_literal: true

RSpec.describe 'Bookt' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/bookt/manifest'), http_mock) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'Connect' => {
        ports: {
          'IConnect' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://connect.bookt.com/svc/connect.svc'
          }
        }
      }
    )
  end

  it 'resolves WSDL imports to get the operations' do
    operations = client.operations('Connect', 'IConnect')

    expect(operations).to be_an(Array)
    expect(operations.count).to eq(26)

    expect(operations).to include('GetBooking')
  end

  it 'resolves XML Schema imports to get all elements' do
    get_booking = client.operation('Connect', 'IConnect', 'GetBooking')

    namespace = 'https://connect.bookt.com/connect'

    expect(get_booking.contract.request.body.paths).to eq([
      { path: ['GetBooking'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[GetBooking apiKey],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[GetBooking bookingID],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[GetBooking useInternalID],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
}
    ])
  end
end
