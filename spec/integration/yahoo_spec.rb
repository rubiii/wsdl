# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Integration with Yahoo\'s AccountService' do
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

    expect(request_body_paths(operation)).to eq([
      [['updateStatusForManagedPublisher'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[updateStatusForManagedPublisher accountID],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[updateStatusForManagedPublisher accountStatus],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
]
    ])
  end

  # multiple implicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    expect(request_template(operation, section: :header)).to eq(
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

    expect(request_template(operation, section: :body)).to eq(
      updateStatusForManagedPublisher: {
        accountID: 'string',
        accountStatus: 'string'
      }
    )
  end

  it 'creates a request with multiple headers' do
    operation = client.operation(service_name, port_name, :updateStatusForManagedPublisher)

    apply_request(operation,
                  header: {
                    Security: {
                      UsernameToken: {
                        Username: 'admin',
                        Password: 'secret'
                      }
                    },
                    license: 'abc-license',
                    accountID: '23'
                  },
                  body: {
                    updateStatusForManagedPublisher: {
                      accountID: '23',
                      accountStatus: 'closed'
                    }
                  })

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
