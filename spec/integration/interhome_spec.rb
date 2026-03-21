# frozen_string_literal: true

RSpec.describe 'Integration with Interhome' do
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

    expect(request_body_paths(operation)).to eq([
      [['ClientBooking'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[ClientBooking inputValue],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[ClientBooking inputValue SalesOfficeCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue AccommodationCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],

      [%w[ClientBooking inputValue AdditionalServices],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem Code],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue AdditionalServices AdditionalServiceInputItem Count],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:int' }
],

      [%w[ClientBooking inputValue CustomerSalutationType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerName],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerFirstName],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerPhone],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerFax],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerEmail],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressStreet],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressAdditionalStreet],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressZIP],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressPlace],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressState],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CustomerAddressCountryCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue Comment],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue Adults],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:int' }
],
      [%w[ClientBooking inputValue Babies],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:int' }
],
      [%w[ClientBooking inputValue Children],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:int' }
],
      [%w[ClientBooking inputValue CheckIn],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CheckOut],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue LanguageCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CurrencyCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue RetailerCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue RetailerExtraCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue PaymentType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CreditCardType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CreditCardNumber],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CreditCardCvc],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CreditCardExpiry],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue CreditCardHolder],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue BankAccountNumber],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue BankCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
 }
],
      [%w[ClientBooking inputValue BankAccountHolder],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:string' }
]
    ])
  end

  # implicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :Availability)

    expect(request_template(operation, section: :header)).to eq(
      ServiceAuthHeader: {
        Username: 'string',
        Password: 'string'
      }
    )
  end

  it 'creates an example body including optional elements' do
    operation = client.operation(service_name, port_name, :Availability)

    expect(request_template(operation, section: :body)).to eq(
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

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url, strict_schema: false) }

    let(:service) { WSDL::TestService[:interhome] }

    before do
      service.start
    end

    it 'returns a successful booking' do
      operation = client.operation(service_name, port_name, :ClientBooking)

      operation.prepare do
        header do
          tag('ServiceAuthHeader') do
            tag('Username', 'test')
            tag('Password', 'secret')
          end
        end
        body do
          tag('ClientBooking') do
            tag('inputValue') do
              tag('AccommodationCode', 'CH1000.100.1')
              tag('CustomerName', 'Smith')
              tag('Adults', 2)
              tag('CheckIn', '2025-06-01')
              tag('CheckOut', '2025-06-08')
            end
          end
        end
      end
      response = operation.invoke

      expect(response.body).to eq(
        ClientBookingResponse: {
          ClientBookingResult: {
            Ok: true,
            BookingID: 'BK-2025-98765'
          }
        }
      )
    end

    it 'returns errors for an invalid accommodation' do
      operation = client.operation(service_name, port_name, :ClientBooking)

      operation.prepare do
        header do
          tag('ServiceAuthHeader') do
            tag('Username', 'test')
            tag('Password', 'secret')
          end
        end
        body do
          tag('ClientBooking') do
            tag('inputValue') do
              tag('AccommodationCode', 'INVALID-999')
              tag('CustomerName', 'Test')
              tag('Adults', 1)
              tag('CheckIn', '2025-07-01')
              tag('CheckOut', '2025-07-08')
            end
          end
        end
      end
      response = operation.invoke

      body = response.body[:ClientBookingResponse][:ClientBookingResult]
      expect(body[:Ok]).to be false
      expect(body[:Errors][:Error]).to eq([
        { Number: 1001, Description: 'Unknown accommodation code' },
        { Number: 1002, Description: 'Please verify your input' }
      ])
    end

    it 'returns a booking with pending payment status' do
      operation = client.operation(service_name, port_name, :ClientBooking)

      operation.prepare do
        header do
          tag('ServiceAuthHeader') do
            tag('Username', 'test')
            tag('Password', 'secret')
          end
        end
        body do
          tag('ClientBooking') do
            tag('inputValue') do
              tag('AccommodationCode', 'CH1000.100.1')
              tag('CustomerName', 'Holiday')
              tag('Adults', 4)
              tag('CheckIn', '2025-12-24')
              tag('CheckOut', '2025-12-31')
            end
          end
        end
      end
      response = operation.invoke

      body = response.body[:ClientBookingResponse][:ClientBookingResult]
      expect(body[:Ok]).to be true
      expect(body[:BookingID]).to eq('BK-2025-XMAS')
      expect(body[:PaymentStatus][:Ok]).to be false
      expect(body[:PaymentStatus][:Errors][:Error]).to eq([
        { Number: 3001, Description: 'Payment pending confirmation' }
      ])
    end
  end
end
