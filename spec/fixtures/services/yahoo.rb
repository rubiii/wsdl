# frozen_string_literal: true

WSDL::TestService.define(:yahoo, wsdl: 'wsdl/yahoo') do
  operation :addManagedAdvertiser do
    on companyName: 'Acme Corp' do
      {
        out: {
          account: {
            ID: 'ADV-12345',
            accountTypes: { AccountType: ['Advertiser'] },
            address: {
              address1: '100 Main Street',
              city: 'Sunnyvale',
              country: 'US',
              postalCode: '94089',
              state: 'CA'
            },
            companyID: 67_890,
            companyName: 'Acme Corp',
            defaultCurrency: 'USD',
            language: 'en',
            location: 'US',
            managedAccount: true,
            managedAgencyBillingEnabled: false,
            status: 'Active',
            timezone: 'America/Los_Angeles',
            yahooOwnedAndOperatedFlag: false
          },
          operationSucceeded: true
        }
      }
    end
  end
end
