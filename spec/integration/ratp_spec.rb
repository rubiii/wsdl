# frozen_string_literal: true

RSpec.describe 'RATP' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:ratp] }
  let(:service_name) { :Wsiv }
  let(:soap12_port) { :WsivSOAP12port_http }

  before do
    service.start
  end

  it 'returns metro lines matching a code' do
    operation = client.operation(service_name, soap12_port, :getLines)

    operation.prepare do
      body do
        tag('getLines') do
          tag('line') do
            tag('code', 'M1')
          end
        end
      end
    end
    response = operation.invoke

    lines = response.body[:getLinesResponse][:return]
    expect(lines).to be_an(Array)
    expect(lines.size).to eq(2)

    expect(lines[0][:name]).to eq('Métro 1')
    expect(lines[0][:reseau][:name]).to eq('Métro')

    expect(lines[1][:code]).to eq('M1b')
  end

  it 'returns an empty array for unknown codes' do
    operation = client.operation(service_name, soap12_port, :getLines)

    operation.prepare do
      body do
        tag('getLines') do
          tag('line') do
            tag('code', 'UNKNOWN')
          end
        end
      end
    end
    response = operation.invoke

    expect(response.body[:getLinesResponse]).to eq({})
  end
end
