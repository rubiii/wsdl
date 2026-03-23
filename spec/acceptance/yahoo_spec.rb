# frozen_string_literal: true

RSpec.describe 'Yahoo\'s AccountService' do
  subject(:client) { WSDL::Client.new fixture('wsdl/yahoo') }

  let(:service_name) { :AccountServiceService }
  let(:port_name)    { :AccountService }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AccountServiceService' => {
        ports: {
          'AccountService' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',

            # symbolic endpoint
            location: 'https://USE_ADDRESS_RETURNED_BY_LOCATION_SERVICE/services/V10/AccountService'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('https://USE_ADDRESS_RETURNED_BY_LOCATION_SERVICE/services/V10/AccountService')

    namespace = 'http://apt.yahooapis.com/V10'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['updateStatusForManagedPublisher'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[updateStatusForManagedPublisher accountID],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[updateStatusForManagedPublisher accountStatus],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
}
    ])
  end

  # multiple implicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    expect(operation.contract.request.header.template(mode: :full).to_h).to eq(
      Security: {
        UsernameToken: {
          Username: 'string',
          Password: 'string'
        }
      },
      license: 'string',
      accountID: 'string'
    )
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      updateStatusForManagedPublisher: {
        accountID: 'string',
        accountStatus: 'string'
      }
    )
  end

  it 'creates a request with multiple headers' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    operation.prepare do
      header do
        tag('Security') do
          tag('UsernameToken') do
            tag('Username', 'admin')
            tag('Password', 'secret')
          end
        end
        tag('license', 'abc-license')
        tag('accountID', '23')
      end
      body do
        tag('updateStatusForManagedPublisher') do
          tag('accountID', '23')
          tag('accountStatus', 'closed')
        end
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://schemas.xmlsoap.org/ws/2002/07/secext"
          xmlns:ns1="http://apt.yahooapis.com/V10"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header>
          <ns0:Security>
            <UsernameToken>
              <Username>admin</Username>
              <Password>secret</Password>
            </UsernameToken>
          </ns0:Security>
          <ns1:license>abc-license</ns1:license>
          <ns1:accountID>23</ns1:accountID>
        </env:Header>
        <env:Body>
          <ns1:updateStatusForManagedPublisher>
            <ns1:accountID>23</ns1:accountID>
            <ns1:accountStatus>closed</ns1:accountStatus>
          </ns1:updateStatusForManagedPublisher>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
