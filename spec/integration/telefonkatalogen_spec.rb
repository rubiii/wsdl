# frozen_string_literal: true

RSpec.describe 'Telefonkatalogen' do
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
