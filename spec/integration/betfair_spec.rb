# frozen_string_literal: true

RSpec.describe 'Integration with Betfair' do
  subject(:client) { WSDL::Client.new fixture('wsdl/betfair') }

  let(:service_name) { :BFExchangeService }
  let(:port_name)    { :BFExchangeService }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'BFExchangeService' => {
        ports: {
          'BFExchangeService' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.betfair.com/exchange/v5/BFExchangeService'
          }
        }
      }
    )
  end

  it 'knows operations with extensions and Arrays' do
    service = port = 'BFExchangeService'
    operation = client.operation(service, port, 'getMUBetsLite')

    expect(operation.soap_action).to eq('getMUBetsLite')
    expect(operation.endpoint).to eq('https://api.betfair.com/exchange/v5/BFExchangeService')

    ns = 'http://www.betfair.com/publicapi/v5/BFExchangeService/'
    ns2 = 'http://www.betfair.com/publicapi/types/exchange/v5/'

    expect(request_body_paths(operation)).to eq([
      [['getMUBetsLite'],
       { namespace: ns, form: 'qualified', singular: true }
],

      [%w[getMUBetsLite request],
       { namespace: ns, form: 'qualified', singular: true }
],

      # extension elements

      [%w[getMUBetsLite request header],
       { namespace: ns2, form: 'unqualified', singular: true }
],

      [%w[getMUBetsLite request header clientStamp],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:long' }
],

      [%w[getMUBetsLite request header sessionToken],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:string' }
],

      # ---

      [%w[getMUBetsLite request betStatus],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:string' }
],

      [%w[getMUBetsLite request marketId],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:int' }
],

      [%w[getMUBetsLite request betIds],
       { namespace: ns2, form: 'unqualified', singular: true }
],

      [%w[getMUBetsLite request betIds betId],
       { namespace: ns2, form: 'qualified', singular: false, type: 'xsd:long' }
],

      [%w[getMUBetsLite request orderBy],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:string' }
],

      [%w[getMUBetsLite request sortOrder],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:string' }
],

      [%w[getMUBetsLite request recordCount],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:int' }
],

      [%w[getMUBetsLite request startRecord],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:int' }
],

      [%w[getMUBetsLite request matchedSince],
       { namespace: ns2, form: 'unqualified', singular: true,
         type: 'xsd:dateTime'
 }
],

      [%w[getMUBetsLite request excludeLastSecond],
       { namespace: ns2, form: 'unqualified', singular: true, type: 'xsd:boolean' }
]
    ])
  end

  it 'creates a proper example request for messages with Arrays' do
    operation = client.operation(service_name, port_name, :getMUBetsLite)

    expect(request_template(operation, section: :body)).to eq(
      getMUBetsLite: {
        request: {

          # This is an extension
          header: {
            clientStamp: 'long',
            sessionToken: 'string'
          },

          betStatus: 'string',
          marketId: 'int',
          betIds: {

            # This is an Array of simpleTypes
            betId: ['long']

          },
          orderBy: 'string',
          sortOrder: 'string',
          recordCount: 'int',
          startRecord: 'int',
          matchedSince: 'dateTime',
          excludeLastSecond: 'boolean'
        }
      }
    )
  end

  it 'builds a request for extensions and Arrays' do
    operation = client.operation(service_name, port_name, :getMUBetsLite)
    datetime_value = (Time.now - 365).xmlschema

    operation.prepare do
      body do
        tag('getMUBetsLite') do
          tag('request') do
            tag('header') do
              tag('clientStamp', 'test')
              tag('sessionToken', 'token')
            end
            tag('betStatus', 'U')
            tag('marketId', 1)
            tag('betIds') do
              tag('betId', 1)
              tag('betId', 2)
              tag('betId', 3)
            end
            tag('orderBy', 'NONE')
            tag('sortOrder', 'DESC')
            tag('recordCount', 10)
            tag('startRecord', 1)
            tag('matchedSince', datetime_value)
            tag('excludeLastSecond', true)
          end
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://www.betfair.com/publicapi/v5/BFExchangeService/"
          xmlns:ns1="http://www.betfair.com/publicapi/types/exchange/v5/"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:getMUBetsLite>
            <ns0:request>
              <header>
                <clientStamp>test</clientStamp>
                <sessionToken>token</sessionToken>
              </header>
              <betStatus>U</betStatus>
              <marketId>1</marketId>
              <betIds>
                <ns1:betId>1</ns1:betId>
                <ns1:betId>2</ns1:betId>
                <ns1:betId>3</ns1:betId>
              </betIds>
              <orderBy>NONE</orderBy>
              <sortOrder>DESC</sortOrder>
              <recordCount>10</recordCount>
              <startRecord>1</startRecord>
              <matchedSince>#{datetime_value}</matchedSince>
              <excludeLastSecond>true</excludeLastSecond>
            </ns0:request>
          </ns0:getMUBetsLite>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url) }

    let(:service) { WSDL::TestService[:betfair] }

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
end
