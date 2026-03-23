# frozen_string_literal: true

RSpec.describe 'Interhome' do
  subject(:client) { WSDL::Client.new fixture('wsdl/interhome') }

  let(:service_name) { :WebService }
  let(:port_name)    { :WebServiceSoap }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'WebService' => {
        ports: {
          'WebServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.interhome.com/quality/partnerV3/WebService.asmx'
          },
          'WebServiceSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'https://webservices.interhome.com/quality/partnerV3/WebService.asmx'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation(service_name, port_name, 'ClientBooking')

    expect(operation.soap_action).to eq('http://www.interhome.com/webservice/ClientBooking')
    expect(operation.endpoint).to eq('https://webservices.interhome.com/quality/partnerV3/WebService.asmx')

    namespace = 'http://www.interhome.com/webservice'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['ClientBooking'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[ClientBooking inputValue],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[ClientBooking inputValue SalesOfficeCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue AccommodationCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue AdditionalServices],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem Code],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem Count],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:int',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerSalutationType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerName],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerFirstName],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerPhone],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerFax],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerEmail],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressStreet],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressAdditionalStreet],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressZIP],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressPlace],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressState],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CustomerAddressCountryCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue Comment],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue Adults],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:int',
        list: false
},
      { path: %w[ClientBooking inputValue Babies],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:int',
        list: false
},
      { path: %w[ClientBooking inputValue Children],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:int',
        list: false
},
      { path: %w[ClientBooking inputValue CheckIn],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CheckOut],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue LanguageCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CurrencyCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue RetailerCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue RetailerExtraCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue PaymentType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CreditCardType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CreditCardNumber],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CreditCardCvc],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CreditCardExpiry],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue CreditCardHolder],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue BankAccountNumber],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue BankCode],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false
},
      { path: %w[ClientBooking inputValue BankAccountHolder],
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

  # implicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :Availability)

    expect(operation.contract.request.header.template(mode: :full).to_h).to eq(
      ServiceAuthHeader: {
        Username: 'string',
        Password: 'string'
      }
    )
  end

  it 'creates an example body including optional elements' do
    operation = client.operation(service_name, port_name, :Availability)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      Availability: {

        # These are optional.
        inputValue: {
          AccommodationCode: 'string',
          CheckIn: 'string',
          CheckOut: 'string'
        }

      }
    )
  end

  it 'skips optional elements in the request' do
    operation = client.operation(service_name, port_name, :Availability)

    operation.prepare do
      header do
        tag('ServiceAuthHeader') do
          tag('Username', 'test')
          tag('Password', 'secret')
        end
      end
      body do
        tag('Availability') do
          tag('inputValue') do
            # Leaving out two optional elements on purpose.
            tag('AccommodationCode', 'secret')
          end
        end
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://www.interhome.com/webservice"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header>
          <ns0:ServiceAuthHeader>
            <ns0:Username>test</ns0:Username>
            <ns0:Password>secret</ns0:Password>
          </ns0:ServiceAuthHeader>
        </env:Header>
        <env:Body>
          <ns0:Availability>
            <ns0:inputValue>
              <ns0:AccommodationCode>secret</ns0:AccommodationCode>
            </ns0:inputValue>
          </ns0:Availability>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
