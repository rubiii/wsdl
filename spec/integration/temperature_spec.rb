# frozen_string_literal: true

RSpec.describe 'Temperature service' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:temperature] }
  let(:service_name) { :ConvertTemperature }

  before do
    service.start
  end

  it 'converts Celsius to Fahrenheit with double precision' do
    operation = client.operation(service_name, :ConvertTemperatureSoap, :ConvertTemp)

    operation.prepare do
      body do
        tag('ConvertTemp') do
          tag('Temperature', 100.0)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    end
    response = operation.invoke

    expect(response.body[:ConvertTempResponse][:ConvertTempResult]).to eq(212.0)
  end

  it 'returns freezing point' do
    operation = client.operation(service_name, :ConvertTemperatureSoap, :ConvertTemp)

    operation.prepare do
      body do
        tag('ConvertTemp') do
          tag('Temperature', 0.0)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    end
    response = operation.invoke

    expect(response.body[:ConvertTempResponse][:ConvertTempResult]).to eq(32.0)
  end
end
