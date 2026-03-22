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

    expect(request_body_paths(get_booking)).to eq([
      [['GetBooking'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[GetBooking apiKey],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[GetBooking bookingID],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[GetBooking useInternalID],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:boolean'
 }
]
    ])
  end
end
