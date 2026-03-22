# frozen_string_literal: true

RSpec.describe 'Stockquote service' do
  subject(:client) { WSDL::Client.new fixture('wsdl/stockquote') }

  let(:service_name) { :StockQuote }
  let(:port_name)    { :StockQuoteSoap }

  it 'creates an example request' do
    operation = client.operation(service_name, port_name, :GetQuote)

    expect(request_template(operation, section: :body)).to eq(
      GetQuote: {
        symbol: 'string'
      }
    )
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :GetQuote)

    operation.reset!
    operation.prepare do
      body do
        tag('GetQuote') do
          tag('symbol', 'AAPL')
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://www.webserviceX.NET/"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:GetQuote>
            <ns0:symbol>AAPL</ns0:symbol>
          </ns0:GetQuote>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
