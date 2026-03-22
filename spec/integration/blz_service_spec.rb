# frozen_string_literal: true

RSpec.describe 'BLZService' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:blz_service] }
  let(:service_name) { :BLZService }
  let(:port_name)    { :BLZServiceSOAP11port_http }

  before do
    service.start
  end

  it 'returns bank details for a known BLZ' do
    operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

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
