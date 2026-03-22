# frozen_string_literal: true

RSpec.describe 'Betfair' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:betfair] }
  let(:service_name) { :BFExchangeService }
  let(:port_name)    { :BFExchangeService }

  before do
    service.start
  end

  it 'returns matched bets with multiple numeric types' do
    operation = client.operation(service_name, port_name, :getMUBetsLite)

    operation.prepare do
      body do
        tag('getMUBetsLite') do
          tag('request') do
            tag('header') do
              tag('clientStamp', 0)
              tag('sessionToken', 'token')
            end
            tag('betStatus', 'MU')
            tag('marketId', 123_456)
            tag('betIds')
            tag('orderBy', 'NONE')
            tag('sortOrder', 'ASC')
            tag('recordCount', 100)
            tag('startRecord', 0)
            tag('matchedSince', '2025-01-01T00:00:00Z')
            tag('excludeLastSecond', false)
          end
        end
      end
    end
    response = operation.invoke
    result = response.body[:getMUBetsLiteResponse][:Result]

    expect(result[:header][:errorCode]).to eq('OK')
    expect(result[:totalRecordCount]).to eq(2)

    bets = result[:betLites][:MUBetLite]
    expect(bets).to be_an(Array)
    expect(bets.size).to eq(2)

    expect(bets[0]).to eq(
      betId: 100_001,
      transactionId: 200_001,
      marketId: 123_456,
      size: 25.5,
      betStatus: 'MU',
      betCategoryType: 'E',
      betPersistenceType: 'NONE',
      bspLiability: 0.0
    )

    expect(bets[1][:betId]).to eq(100_002)
    expect(bets[1][:size]).to eq(10.0)
    expect(bets[1][:bspLiability]).to eq(5.75)
  end

  it 'returns an empty result for a market with no bets' do
    operation = client.operation(service_name, port_name, :getMUBetsLite)

    operation.prepare do
      body do
        tag('getMUBetsLite') do
          tag('request') do
            tag('header') do
              tag('clientStamp', 0)
              tag('sessionToken', 'token')
            end
            tag('betStatus', 'MU')
            tag('marketId', 999_999)
            tag('betIds')
            tag('orderBy', 'NONE')
            tag('sortOrder', 'ASC')
            tag('recordCount', 100)
            tag('startRecord', 0)
            tag('matchedSince', '2025-01-01T00:00:00Z')
            tag('excludeLastSecond', false)
          end
        end
      end
    end
    response = operation.invoke
    result = response.body[:getMUBetsLiteResponse][:Result]

    expect(result[:totalRecordCount]).to eq(0)
    expect(result[:betLites]).to eq({})
  end
end
