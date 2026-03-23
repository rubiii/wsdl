# frozen_string_literal: true

RSpec.describe 'Jetairways\'s SessionCreate Service' do
  subject(:client) { WSDL::Client.new fixture('wsdl/jetairways') }

  let(:service_name) { :SessionCreate }
  let(:port_name)    { :SessionCreateSoap }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'SessionCreate' => {
        ports: {
          'SessionCreateSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            # symbolic endpoint
            location: 'http://USE_ADDRESS_RETURNED_BY_LOCATION_SERVICE/jettaobeapi/SessionCreate.asmx',
            operations: [{ name: 'Logon' }]
          },
          'SessionCreateSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            # symbolic endpoint
            location: 'http://USE_ADDRESS_RETURNED_BY_LOCATION_SERVICE/jettaobeapi/SessionCreate.asmx',
            operations: [{ name: 'Logon' }]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation(service_name, port_name, :Logon)

    expect(operation.soap_action).to eq('http://www.vedaleon.com/webservices/Logon')
    expect(operation.endpoint).to eq('http://USE_ADDRESS_RETURNED_BY_LOCATION_SERVICE/jettaobeapi/SessionCreate.asmx')

    namespace = 'http://www.vedaleon.com/webservices'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Logon'], kind: :complex, namespace: namespace, form: 'qualified',
        singular: true, min_occurs: '1', max_occurs: '1', wildcard: false
}
    ])
  end

  # multiple implicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :Logon)

    expect(operation.contract.request.header.template(mode: :full).to_h).to eq(
      MessageHeader:
        { From: { PartyId: [{ _type: 's:string' }], Role: 'string' },
          To: { PartyId: [{ _type: 's:string' }], Role: 'string' },
          CPAId: 'string',
          ConversationId: 'string',
          Service: { _type: 's:string' },
          Action: 'string',
          MessageData:
          { MessageId: 'string',
            Timestamp: 'string',
            RefToMessageId: 'string',
            TimeToLive: 'dateTime'
},
          DuplicateElimination: {},
          Description: [{}],
          _id: 's:ID',
          _version: 's:string'
},
      Security:
       { UsernameToken:
         { Username: 'string',
           Password: 'string',
           Organization: 'string',
           Domain: 'string'
},
         BinarySecurityToken: 'string'
}
    )
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :Logon)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      Logon: {}
    )
  end

  it 'creates a request with multiple headers' do
    operation = client.operation(service_name, port_name, :Logon)

    operation.prepare do
      header do
        tag('MessageHeader') do
          tag('CPAId', '9W')
          tag('ConversationId', '1')
          tag('Service', 'Create')
          tag('Action', 'CreateSession')
          tag('MessageData') do
            tag('MessageId', '0')
            tag('Timestamp', '2014-02-01T12:57:12.000Z')
          end
        end
        tag('Security') do
          tag('UsernameToken') do
            tag('Username', 'example_user')
            tag('Password', 'my_secret')
            tag('Organization', 'example_organization')
          end
        end
      end
      body do
        tag('Logon')
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
       xmlns:ns0="http://www.ebxml.org/namespaces/messageHeader"
       xmlns:ns1="http://schemas.xmlsoap.org/ws/2002/12/secext"
       xmlns:ns2="http://www.vedaleon.com/webservices"
       xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header>
          <ns0:MessageHeader>
            <ns0:CPAId>9W</ns0:CPAId>
            <ns0:ConversationId>1</ns0:ConversationId>
            <ns0:Service>Create</ns0:Service>
            <ns0:Action>CreateSession</ns0:Action>
            <ns0:MessageData>
              <ns0:MessageId>0</ns0:MessageId>
              <ns0:Timestamp>2014-02-01T12:57:12.000Z</ns0:Timestamp>
            </ns0:MessageData>
          </ns0:MessageHeader>
          <ns1:Security>
            <ns1:UsernameToken>
              <ns1:Username>example_user</ns1:Username>
              <ns1:Password>my_secret</ns1:Password>
              <Organization>example_organization</Organization>
            </ns1:UsernameToken>
          </ns1:Security>
        </env:Header>
        <env:Body>
          <ns2:Logon/>
        </env:Body>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
