# frozen_string_literal: true

WSDL::TestService.define(:authentication, wsdl: 'wsdl/authentication') do
  operation :authenticate do
    on user: 'admin', password: 'secret' do
      {
        return: {
          authenticationValue: {
            token: 'a68d1c97-00e4-4caf-a8d0-1d3b08ee5d3b',
            tokenHash: 'a1b2c3d4e5f6',
            client: 'admin-console'
          },
          success: true
        }
      }
    end

    on user: 'admin', password: 'wrong' do
      {
        return: {
          success: false
        }
      }
    end
  end
end
