# frozen_string_literal: true

WSDL::TestService.define(:interhome, wsdl: 'wsdl/interhome') do
  operation :ClientBooking do
    on AccommodationCode: 'CH1000.100.1', CheckIn: '2025-06-01', CheckOut: '2025-06-08' do
      {
        ClientBookingResult: {
          Ok: true,
          BookingID: 'BK-2025-98765'
        }
      }
    end

    on AccommodationCode: 'INVALID-999' do
      {
        ClientBookingResult: {
          Ok: false,
          Errors: {
            Error: [
              { Number: 1001, Description: 'Unknown accommodation code' },
              { Number: 1002, Description: 'Please verify your input' }
            ]
          }
        }
      }
    end

    on AccommodationCode: 'CH1000.100.1', CheckIn: '2025-12-24', CheckOut: '2025-12-31' do
      {
        ClientBookingResult: {
          Ok: true,
          BookingID: 'BK-2025-XMAS',
          PaymentStatus: {
            Ok: false,
            Errors: {
              Error: [
                { Number: 3001, Description: 'Payment pending confirmation' }
              ]
            }
          }
        }
      }
    end
  end
end

RSpec.describe 'Interhome' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:interhome] }
  let(:service_name) { :WebService }
  let(:port_name)    { :WebServiceSoap }

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
            tag('CustomerSalutationType', 'Mr')
            tag('CustomerName', 'Smith')
            tag('Adults', 2)
            tag('Babies', 0)
            tag('Children', 0)
            tag('CheckIn', '2025-06-01')
            tag('CheckOut', '2025-06-08')
            tag('PaymentType', 'CreditCard')
            tag('CreditCardType', 'Visa')
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
            tag('CustomerSalutationType', 'Mr')
            tag('CustomerName', 'Test')
            tag('Adults', 1)
            tag('Babies', 0)
            tag('Children', 0)
            tag('CheckIn', '2025-07-01')
            tag('CheckOut', '2025-07-08')
            tag('PaymentType', 'CreditCard')
            tag('CreditCardType', 'Visa')
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
            tag('CustomerSalutationType', 'Mr')
            tag('CustomerName', 'Holiday')
            tag('Adults', 4)
            tag('Babies', 0)
            tag('Children', 0)
            tag('CheckIn', '2025-12-24')
            tag('CheckOut', '2025-12-31')
            tag('PaymentType', 'CreditCard')
            tag('CreditCardType', 'Visa')
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
