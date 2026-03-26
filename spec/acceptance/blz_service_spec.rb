# frozen_string_literal: true

RSpec.describe 'BLZService' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/blz_service')) }

  let(:service_name) { :BLZService }
  let(:port_name)    { :BLZServiceSOAP11port_http }

  it 'creates an example request' do
    operation = client.operation(service_name, port_name, :getBank)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      getBank: {
        blz: 'string'
      }
    )
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :getBank)

    operation.prepare do
      body do
        tag('getBank') do
          tag('blz', 70_070_010)
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://thomas-bayer.com/blz/"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:getBank>
            <ns0:blz>70070010</ns0:blz>
          </ns0:getBank>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
