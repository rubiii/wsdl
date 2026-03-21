# frozen_string_literal: true

WSDL::TestService.define(:betfair, wsdl: 'wsdl/betfair') do
  operation :getMUBetsLite do
    on marketId: 123_456, betStatus: 'MU' do
      {
        Result: {
          header: {
            errorCode: 'OK',
            minorErrorCode: '',
            sessionToken: 'sess-abc-123',
            timestamp: '2025-06-01T12:00:00Z'
          },
          betLites: {
            MUBetLite: [
              {
                betId: 100_001,
                transactionId: 200_001,
                marketId: 123_456,
                size: 25.50,
                betStatus: 'MU',
                betCategoryType: 'E',
                betPersistenceType: 'NONE',
                bspLiability: 0.0
              },
              {
                betId: 100_002,
                transactionId: 200_002,
                marketId: 123_456,
                size: 10.0,
                betStatus: 'MU',
                betCategoryType: 'E',
                betPersistenceType: 'IP',
                bspLiability: 5.75
              }
            ]
          },
          errorCode: 'OK',
          minorErrorCode: '',
          totalRecordCount: 2
        }
      }
    end

    on marketId: 999_999, betStatus: 'MU' do
      {
        Result: {
          header: {
            errorCode: 'OK',
            minorErrorCode: '',
            sessionToken: 'sess-abc-123',
            timestamp: '2025-06-01T12:00:00Z'
          },
          betLites: {},
          errorCode: 'OK',
          minorErrorCode: '',
          totalRecordCount: 0
        }
      }
    end
  end
end
