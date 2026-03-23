# frozen_string_literal: true

RSpec.describe 'Xignite' do
  # reference: http://www.xignite.com/product/global-security-master-data/api/GetSecurities/
  subject(:client) { WSDL::Client.new fixture('wsdl/xignite') }

  let(:service_name) { :XigniteGlobalMaster }
  let(:port_name)    { :XigniteGlobalMasterSoap12 }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'XigniteGlobalMaster' => {
        ports: {
          'XigniteGlobalMasterSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://globalmaster.xignite.com/xglobalmaster.asmx',
            operations: [
              { name: 'GetSecurity' },
              { name: 'GetSecurities' },
              { name: 'GetInstrument' },
              { name: 'GetInstruments' },
              { name: 'GetIssuer' },
              { name: 'GetIssuers' },
              { name: 'GetIssuerByCompanyIdentifier' },
              { name: 'GetMasterByIdentifier' },
              { name: 'GetMasterByIdentifiers' },
              { name: 'GetMasterByExchange' },
              { name: 'GetMasterByExchangeChanges' },
              { name: 'GetMasterBySector' },
              { name: 'GetMasterByIndustry' },
              { name: 'ListExchanges' },
              { name: 'ListIndustries' },
              { name: 'ListSectors' },
              { name: 'ListMICToLegacyExchange' },
              { name: 'ListMICToLegacySuffix' },
              { name: 'ListIdentifiersByExchange' },
              { name: 'GetMasterStatisticsByExchange' }
            ]
          },
          'XigniteGlobalMasterSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'http://globalmaster.xignite.com/xglobalmaster.asmx',
            operations: [
              { name: 'GetSecurity' },
              { name: 'GetSecurities' },
              { name: 'GetInstrument' },
              { name: 'GetInstruments' },
              { name: 'GetIssuer' },
              { name: 'GetIssuers' },
              { name: 'GetIssuerByCompanyIdentifier' },
              { name: 'GetMasterByIdentifier' },
              { name: 'GetMasterByIdentifiers' },
              { name: 'GetMasterByExchange' },
              { name: 'GetMasterByExchangeChanges' },
              { name: 'GetMasterBySector' },
              { name: 'GetMasterByIndustry' },
              { name: 'ListExchanges' },
              { name: 'ListIndustries' },
              { name: 'ListSectors' },
              { name: 'ListMICToLegacyExchange' },
              { name: 'ListMICToLegacySuffix' },
              { name: 'ListIdentifiersByExchange' },
              { name: 'GetMasterStatisticsByExchange' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    expect(operation.soap_action).to eq('http://www.xignite.com/services/GetSecurities')
    expect(operation.endpoint).to eq('http://globalmaster.xignite.com/xglobalmaster.asmx')

    namespace = 'http://www.xignite.com/services/'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['GetSecurities'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[GetSecurities Identifiers],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[GetSecurities IdentifierType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[GetSecurities AsOfDate],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
}
    ])
  end

  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    expect(operation.contract.request.header.template(mode: :full).to_h).to eq(
      Header: {
        Username: 'string',
        Password: 'string',
        Tracer: 'string'
      }
    )
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      GetSecurities: {
        Identifiers: 'string',
        IdentifierType: 'string',
        AsOfDate: 'string'
      }
    )
  end

  it 'creates a request with a header' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    operation.prepare do
      header do
        tag('Header') do
          tag('Username', 'test')
          tag('Password', 'secret')
          tag('Tracer', 'i-dont-know')
        end
      end
      body do
        tag('GetSecurities') do
          tag('Identifiers', 'NESN.XVTX,BMW.XETR')
          tag('IdentifierType', 'Symbol')
          tag('AsOfDate', '6/4/2013')
        end
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://www.xignite.com/services/"
          xmlns:env="http://www.w3.org/2003/05/soap-envelope">
        <env:Header>
          <ns0:Header>
            <ns0:Username>test</ns0:Username>
            <ns0:Password>secret</ns0:Password>
            <ns0:Tracer>i-dont-know</ns0:Tracer>
          </ns0:Header>
        </env:Header>
        <env:Body>
          <ns0:GetSecurities>
            <ns0:Identifiers>NESN.XVTX,BMW.XETR</ns0:Identifiers>
            <ns0:IdentifierType>Symbol</ns0:IdentifierType>
            <ns0:AsOfDate>6/4/2013</ns0:AsOfDate>
          </ns0:GetSecurities>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
