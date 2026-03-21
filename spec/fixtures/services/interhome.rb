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
