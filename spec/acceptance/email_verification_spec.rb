# frozen_string_literal: true

RSpec.describe 'EmailVerification service' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/email_verification')) }

  let(:service_name) { :EmailVerNoTestEmail }
  let(:port_name)    { :EmailVerNoTestEmailSoap12 }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'EmailVerNoTestEmail' => {
        ports: {
          'EmailVerNoTestEmailSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://ws.cdyne.com/emailverify/Emailvernotestemail.asmx',
            operations: [
              { name: 'VerifyMXRecord' },
              { name: 'AdvancedVerifyEmail' },
              { name: 'VerifyEmail' },
              { name: 'ReturnCodes' }
            ]
          },
          'EmailVerNoTestEmailSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'http://ws.cdyne.com/emailverify/Emailvernotestemail.asmx',
            operations: [
              { name: 'VerifyMXRecord' },
              { name: 'AdvancedVerifyEmail' },
              { name: 'VerifyEmail' },
              { name: 'ReturnCodes' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'EmailVerNoTestEmail'
    port = 'EmailVerNoTestEmailSoap12'
    operation = client.operation(service, port, 'VerifyEmail')

    expect(operation.soap_action).to eq('http://ws.cdyne.com/VerifyEmail')
    expect(operation.endpoint).to eq('http://ws.cdyne.com/emailverify/Emailvernotestemail.asmx')

    namespace = 'http://ws.cdyne.com/'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['VerifyEmail'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[VerifyEmail email],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[VerifyEmail LicenseKey],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
}
    ])
  end

  it 'creates an example request' do
    operation = client.operation(service_name, port_name, :VerifyEmail)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      VerifyEmail: {
        email: 'string',
        LicenseKey: 'string'
      }
    )
  end

  it 'builds a request' do
    operation = client.operation(service_name, port_name, :VerifyEmail)

    operation.prepare do
      body do
        tag('VerifyEmail') do
          tag('email', 'soap@example.com')
          tag('LicenseKey', '?')
        end
      end
    end

    expected = Nokogiri.XML(%(
      <env:Envelope
          xmlns:ns0="http://ws.cdyne.com/"
          xmlns:env="http://www.w3.org/2003/05/soap-envelope">
        <env:Header/>
        <env:Body>
          <ns0:VerifyEmail>
            <ns0:email>soap@example.com</ns0:email>
            <ns0:LicenseKey>?</ns0:LicenseKey>
          </ns0:VerifyEmail>
        </env:Body>
      </env:Envelope>
    ))

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
