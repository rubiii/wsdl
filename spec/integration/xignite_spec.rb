# frozen_string_literal: true

WSDL::TestService.define(:xignite, wsdl: 'wsdl/xignite') do
  operation :GetMasterByIdentifier do
    on Identifier: 'AAPL', IdentifierType: 'Symbol' do
      {
        GetMasterByIdentifierResult: {
          Record: [
            {
              Outcome: 'Success',
              Message: '',
              Identity: 'N/A',
              Delay: 0.0,
              Symbol: 'AAPL',
              Name: 'Apple Inc.',
              CUSIP: '037833100',
              CIK: '320193',
              Valoren: '',
              ISIN: 'US0378331005',
              SEDOL: '2046251',
              CFICode: 'ESVUFR',
              InstrumentClass: 'Equity',
              ExchangeName: 'NASDAQ',
              Sector: 'Technology',
              Industry: 'Consumer Electronics',
              Exchange: 'XNAS',
              Currency: 'USD',
              ActiveDate: '1980-12-12',
              InactiveDate: '',
              LastUpdateDate: '2025-01-15',
              HomeTradingPlace: true,
              CompanyIdentifier: 'AAPL-US'
            }
          ]
        }
      }
    end
  end
end

RSpec.describe 'Xignite' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:xignite] }
  let(:service_name) { :XigniteGlobalMaster }
  let(:soap_port) { :XigniteGlobalMasterSoap }

  before do
    service.start
  end

  it 'returns master data with headers, arrays, and mixed types' do
    operation = client.operation(service_name, soap_port, :GetMasterByIdentifier)

    operation.prepare do
      header do
        tag('Header') do
          tag('Username', 'testuser')
          tag('Password', 'testpass')
          tag('Tracer', '')
        end
      end
      body do
        tag('GetMasterByIdentifier') do
          tag('Identifier', 'AAPL')
          tag('IdentifierType', 'Symbol')
          tag('StartDate', '')
          tag('EndDate', '')
        end
      end
    end
    response = operation.invoke
    result = response.body[:GetMasterByIdentifierResponse][:GetMasterByIdentifierResult]

    records = result[:Record]
    expect(records).to be_an(Array)
    expect(records.size).to eq(1)

    record = records.first
    expect(record[:Symbol]).to eq('AAPL')
    expect(record[:Name]).to eq('Apple Inc.')
    expect(record[:ISIN]).to eq('US0378331005')
    expect(record[:Delay]).to eq(0.0)
    expect(record[:HomeTradingPlace]).to be true
    expect(record[:Sector]).to eq('Technology')
  end
end
