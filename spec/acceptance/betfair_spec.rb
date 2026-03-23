# frozen_string_literal: true

RSpec.describe 'Betfair' do
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

    expect(operation.contract.request.body.paths).to eq([
      { path: ['getMUBetsLite'],
        kind: :complex,
        namespace: ns,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[getMUBetsLite request],
        kind: :complex,
        namespace: ns,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[getMUBetsLite request header],
        kind: :complex,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[getMUBetsLite request header clientStamp],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:long',
        list: false
},
      { path: %w[getMUBetsLite request header sessionToken],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[getMUBetsLite request betStatus],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[getMUBetsLite request marketId],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:int',
        list: false
},
      { path: %w[getMUBetsLite request betIds],
        kind: :complex,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[getMUBetsLite request betIds betId],
        kind: :simple,
        namespace: ns2,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: '1000',
        type: 'xsd:long',
        list: false
},
      { path: %w[getMUBetsLite request orderBy],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[getMUBetsLite request sortOrder],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[getMUBetsLite request recordCount],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:int',
        list: false
},
      { path: %w[getMUBetsLite request startRecord],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:int',
        list: false
},
      { path: %w[getMUBetsLite request matchedSince],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:dateTime',
        list: false
},
      { path: %w[getMUBetsLite request excludeLastSecond],
        kind: :simple,
        namespace: ns2,
        form: 'unqualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:boolean',
        list: false
}
    ])
  end

  it 'creates a proper example request for messages with Arrays' do
    operation = client.operation(service_name, port_name, :getMUBetsLite)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
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
end
