# frozen_string_literal: true

RSpec.describe 'RPC/Literal example' do
  subject(:client) { WSDL::Client.new fixture('wsdl/rpc_literal') }

  let(:service_name) { :SampleService }
  let(:port_name)    { :Sample }

  it 'works with op1' do
    op1 = client.operation(service_name, port_name, :op1)

    # Check the example request.
    expect(op1.contract.request.body.template(mode: :full).to_h).to eq(
      in: {
        data1: 'int',
        data2: 'int'
      }
    )

    # Build the request. It returns a Hash without the RPC wrapper element,
    # because users just don't need to care about it.
    op1.prepare do
      body do
        tag('in') do
          tag('data1', 24)
          tag('data2', 36)
        end
      end
    end

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

    # Check the example request.
    expect(op3.contract.request.body.template(mode: :full).to_h).to eq(
      DataElem: {
        data1: 'int',
        data2: 'int'
      },
      in2: {
        RefDataElem: 'int'
      }
    )

    op3.prepare do
      body do
        tag('DataElem') do
          tag('data1', 64)
          tag('data2', 128)
        end
        tag('in2') do
          tag('RefDataElem', 3)
        end
      end
    end

    # The expected request. Notice how the RPC wrapper element 'op3' is not
    # namespaced because the WSDL does not define a namespace for it.
    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://dataNamespace.com"
          xmlns:ns1="http://refNamespace.com"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <op3>
            <ns0:DataElem>
              <data1>64</data1>
              <data2>128</data2>
            </ns0:DataElem>
            <in2>
              <ns1:RefDataElem>3</ns1:RefDataElem>
            </in2>
          </op3>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(op3.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
