# frozen_string_literal: true

RSpec.describe 'Temperature service' do
  subject(:client) { WSDL::Client.new fixture('wsdl/temperature') }

  let(:service_name) { :ConvertTemperature }
  let(:port_name)    { :ConvertTemperatureSoap12 }

  it 'returns an empty Hash if there are no header parts' do
    operation = client.operation(service_name, port_name, :ConvertTemp)
    expect(request_template(operation, section: :header)).to eq({})
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :ConvertTemp)

    expect(request_template(operation, section: :body)).to eq(
      ConvertTemp: {
        Temperature: 'double',
        FromUnit: 'string',
        ToUnit: 'string'
      }
    )
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :ConvertTemp)

    # For the corrent values to pass for :from_unit and :to_unit, I searched the WSDL for
    # the 'FromUnit' type which is a 'TemperatureUnit' enumeration that looks like this:
    #
    # <s:simpleType name='TemperatureUnit'>
    #   <s:restriction base='s:string'>
    #     <s:enumeration value='degreeCelsius'/>
    #     <s:enumeration value='degreeFahrenheit'/>
    #     <s:enumeration value='degreeRankine'/>
    #     <s:enumeration value='degreeReaumur'/>
    #     <s:enumeration value='kelvin'/>
    #   </s:restriction>
    # </s:simpleType>
    #
    # TODO: somehow expose the enumeration options through the example request.
    operation.reset!
    operation.prepare do
      body do
        tag('ConvertTemp') do
          tag('Temperature', 30)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://www.webserviceX.NET/"
          xmlns:env="http://www.w3.org/2003/05/soap-envelope">
        <env:Header/>
        <env:Body>
          <ns0:ConvertTemp>
            <ns0:Temperature>30</ns0:Temperature>
            <ns0:FromUnit>degreeCelsius</ns0:FromUnit>
            <ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>
          </ns0:ConvertTemp>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
