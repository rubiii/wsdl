# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Integration with BLZService' do
  subject(:client) { WSDL::Client.new fixture('wsdl/blz_service') }

  let(:service_name) { :BLZService }
  let(:port_name)    { :BLZServiceSOAP11port_http }

  it 'creates an example request' do
    operation = client.operation(service_name, port_name, :getBank)

    expect(request_template(operation, section: :body)).to eq(
      getBank: {
        blz: 'string'
      }
    )
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :getBank)

    apply_request(operation, body: {
      getBank: {
        blz: 70_070_010
      }
    })

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
