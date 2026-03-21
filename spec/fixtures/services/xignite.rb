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
