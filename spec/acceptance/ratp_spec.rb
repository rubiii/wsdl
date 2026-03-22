# frozen_string_literal: true

RSpec.describe 'RATP' do
  subject(:client) { WSDL::Client.new fixture('wsdl/ratp') }

  let(:service_name) { :Wsiv }
  let(:port_name)    { :WsivSOAP11port_http }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'Wsiv' => {
        ports: {
          'WsivSOAP11port_http' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://www.ratp.fr/wsiv/services/Wsiv'
          },
          'WsivSOAP12port_http' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'http://www.ratp.fr/wsiv/services/Wsiv'
          }
        }
      }
    )
  end

  it 'gracefully handle recursive type definitions' do
    service = 'Wsiv'
    port = 'WsivSOAP11port_http'
    operation = client.operation(service, port, 'getStations')

    expect(operation.soap_action).to eq('urn:getStations')
    expect(operation.endpoint).to eq('http://www.ratp.fr/wsiv/services/Wsiv')

    ns1 = 'http://wsiv.ratp.fr'
    ns2 = 'http://wsiv.ratp.fr/xsd'

    expect(request_body_paths(operation)).to eq([
      [['getStations'],
       { namespace: ns1, form: 'qualified', singular: true }
],
      [%w[getStations station],
       { namespace: ns1, form: 'qualified', singular: true }
],
      [%w[getStations station direction],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station direction line],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station direction line code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line codeStif],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line realm],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line reseau],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station direction line reseau code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line reseau id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line reseau image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction line reseau name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station direction sens],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],

      [%w[getStations station direction stationsEndLine],
       # Notice how this recursively references its parent type, so we return the
       # type it references as the :recursive_type.
       { namespace: ns2, form: 'qualified', singular: false,
         recursive_type: 'ax21:Station'
}
],

      [%w[getStations station geoPointA],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station geoPointA id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointA name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointA nameSuffix],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointA type],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointA x],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station geoPointA y],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station geoPointR],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station geoPointR id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointR name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointR nameSuffix],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointR type],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station geoPointR x],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station geoPointR y],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station idsNextA],
       { namespace: ns2, form: 'qualified', singular: false, type: 'xs:string' }
],
      [%w[getStations station idsNextR],
       { namespace: ns2, form: 'qualified', singular: false, type: 'xs:string' }
],
      [%w[getStations station line],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station line code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line codeStif],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line realm],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line reseau],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station line reseau code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line reseau id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line reseau image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station line reseau name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station stationArea access],
       { namespace: ns2, form: 'qualified', singular: false }
],
      [%w[getStations station stationArea access address],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access index],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access timeDaysLabel],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access timeDaysStatus],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access timeEnd],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access timeStart],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea access x],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station stationArea access y],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations station stationArea id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],

      [%w[getStations station stationArea stations],
       # Another recursive type definition.
       { namespace: ns2, form: 'qualified', singular: false,
         recursive_type: 'ax21:Station'
}
],

      [%w[getStations station stationArea tarifsToParis],
       { namespace: ns2, form: 'qualified', singular: false }
],
      [%w[getStations station stationArea tarifsToParis demiTarif],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:float' }
],
      [%w[getStations station stationArea tarifsToParis pleinTarif],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:float' }
],
      [%w[getStations station stationArea tarifsToParis viaLine],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station stationArea tarifsToParis viaLine code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine codeStif],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine realm],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine reseau],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station stationArea tarifsToParis viaLine reseau code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine reseau id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine reseau image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaLine reseau name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaReseau],
       { namespace: ns2, form: 'qualified', singular: true }
],
      [%w[getStations station stationArea tarifsToParis viaReseau code],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaReseau id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaReseau image],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea tarifsToParis viaReseau name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations station stationArea zoneCarteOrange],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],

      [%w[getStations gp], { namespace: ns1, form: 'qualified', singular: true }],
      [%w[getStations gp id],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations gp name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations gp nameSuffix],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations gp type],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:string' }
],
      [%w[getStations gp x],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations gp y],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xs:double' }
],
      [%w[getStations distances],
       { namespace: ns1, form: 'qualified', singular: false, type: 'xs:int' }
],
      [%w[getStations limit],
       { namespace: ns1, form: 'qualified', singular: true, type: 'xs:int' }
],
      [%w[getStations sortAlpha],
       { namespace: ns1, form: 'qualified', singular: true, type: 'xs:boolean' }
]
    ])
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :getStations)

    operation.reset!
    operation.prepare do
      body do
        tag('getStations') do
          tag('station') do
            tag('id', 1975)
          end
          tag('limit', 1)
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://wsiv.ratp.fr"
          xmlns:ns1="http://wsiv.ratp.fr/xsd"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header/>
        <env:Body>
          <ns0:getStations>
            <ns0:station>
              <ns1:id>1975</ns1:id>
            </ns0:station>
            <ns0:limit>1</ns0:limit>
          </ns0:getStations>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
