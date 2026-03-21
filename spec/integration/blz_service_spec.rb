# frozen_string_literal: true

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

    operation.reset!
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

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url) }

    let(:service) { WSDL::TestService[:blz_service] }

    before do
      service.start
    end

    it 'returns bank details for a known BLZ' do
      operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

      operation.reset!
      operation.prepare do
        body do
          tag('getBank') do
            tag('blz', '70070010')
          end
        end
      end
      response = operation.invoke

      expect(response.body).to eq(
        getBankResponse: {
          details: {
            bezeichnung: 'Deutsche Bank',
            bic: 'DEUTDEMM',
            ort: 'München',
            plz: '80271'
          }
        }
      )
    end

    it 'returns different results for different inputs' do
      operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

      operation.reset!
      operation.prepare do
        body do
          tag('getBank') do
            tag('blz', '20050550')
          end
        end
      end
      response = operation.invoke

      expect(response.body).to eq(
        getBankResponse: {
          details: {
            bezeichnung: 'Hamburger Sparkasse',
            bic: 'HASPDEHHXXX',
            ort: 'Hamburg',
            plz: '20454'
          }
        }
      )
    end
  end
end
