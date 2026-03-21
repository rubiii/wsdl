# frozen_string_literal: true

RSpec.describe 'Integration with Telefonkatalogen' do
  # reference: savon#295
  subject(:client) { WSDL::Client.new fixture('wsdl/telefonkatalogen') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'SendSms' => {
        ports: {
          'SendSmsPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://bedrift.telefonkatalogen.no/tk/websvcsendsms.php'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation('SendSms', 'SendSmsPort', 'sendsms')

    expect(operation.soap_action).to eq('sendsms')

    # notice how this contains 9 parts with one element each.
    # it does not include the rpc wrapper.

    expect(request_body_paths(operation)).to eq([
      [['sender'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['cellular'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['msg'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['smsnumgroup'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['emailaddr'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['udh'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['datetime'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['format'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
],
      [['dlrurl'],
       { namespace: nil, form: 'unqualified', singular: true, type: 'xsd:string' }
]
    ])
  end

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url) }

    let(:service) { WSDL::TestService[:telefonkatalogen] }
    let(:service_name) { :SendSms }
    let(:port_name) { :SendSmsPort }

    before do
      service.start
    end

    it 'routes by SOAPAction and returns a simple RPC response' do
      operation = client.operation(service_name, port_name, :sendsms)

      operation.prepare do
        body do
          tag('sender', 'MyApp')
          tag('cellular', '4712345678')
          tag('msg', 'Hello')
          tag('smsnumgroup', '')
          tag('emailaddr', '')
          tag('udh', '')
          tag('datetime', '')
          tag('format', '')
          tag('dlrurl', '')
        end
      end
      response = operation.invoke

      expect(response.body[:sendsmsResponse][:body]).to eq('OK: Message queued')
    end

    it 'returns an error for an invalid number' do
      operation = client.operation(service_name, port_name, :sendsms)

      operation.prepare do
        body do
          tag('sender', 'MyApp')
          tag('cellular', '0000000000')
          tag('msg', 'Test')
          tag('smsnumgroup', '')
          tag('emailaddr', '')
          tag('udh', '')
          tag('datetime', '')
          tag('format', '')
          tag('dlrurl', '')
        end
      end
      response = operation.invoke

      expect(response.body[:sendsmsResponse][:body]).to eq('ERROR: Invalid number')
    end
  end
end
