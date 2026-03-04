# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Xignite' do
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
            location: 'http://globalmaster.xignite.com/xglobalmaster.asmx'
          },
          'XigniteGlobalMasterSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'http://globalmaster.xignite.com/xglobalmaster.asmx'
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

    expect(request_body_paths(operation)).to eq([
      [['GetSecurities'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[GetSecurities Identifiers],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[GetSecurities IdentifierType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[GetSecurities AsOfDate],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:string' }
]
    ])
  end

  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    expect(request_template(operation, section: :header)).to eq(
      Header: {
        Username: 'string',
        Password: 'string',
        Tracer: 'string'
      }
    )
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    expect(request_template(operation, section: :body)).to eq(
      GetSecurities: {
        Identifiers: 'string',
        IdentifierType: 'string',
        AsOfDate: 'string'
      }
    )
  end

  it 'creates a request with a header' do
    operation = client.operation(service_name, port_name, :GetSecurities)

    apply_request(operation,
                  header: {
                    Header: {
                      Username: 'test',
                      Password: 'secret',
                      Tracer: 'i-dont-know'
                    }
                  },
                  body: {
                    GetSecurities: {
                      Identifiers: 'NESN.XVTX,BMW.XETR',
                      IdentifierType: 'Symbol',
                      AsOfDate: '6/4/2013'
                    }
                  })

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
