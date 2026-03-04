# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with a Document/Literal example' do
  subject(:client) { WSDL::Client.new fixture('wsdl/document_literal_wrapped') }

  let(:service_name) { :SampleService }
  let(:port_name)    { :Sample }

  it 'works with op1' do
    op1 = client.operation(service_name, port_name, :op1)

    expect(request_template(op1, section: :body)).to eq(
      op1: {
        in: {
          data1: 'int',
          data2: 'int'
        }
      }
    )

    apply_request(op1, body: {
      op1: {
        in: {
          data1: 24,
          data2: 36
        }
      }
    })

    # The expected request.
    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://apiNamespace.com"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:op1>
            <in>
              <data1>24</data1>
              <data2>36</data2>
            </in>
          </ns0:op1>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(op1.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end

  it 'works with op3' do
    op3 = client.operation(service_name, port_name, :op3)

    expect(request_template(op3, section: :body)).to eq(
      op3: {
        DataElem: {
          data1: 'int',
          data2: 'int'
        },
        in2: {
          RefDataElem: 'int'
        }
      }
    )

    apply_request(op3, body: {
      op3: {
        DataElem: {
          data1: 64,
          data2: 128
        },
        in2: {
          RefDataElem: 3
        }
      }
    })

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://apiNamespace.com"
          xmlns:ns1="http://dataNamespace.com"
          xmlns:ns2="http://refNamespace.com"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:op3>
            <ns1:DataElem>
              <data1>64</data1>
              <data2>128</data2>
            </ns1:DataElem>
            <in2>
              <ns2:RefDataElem>3</ns2:RefDataElem>
            </in2>
          </ns0:op3>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(op3.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
