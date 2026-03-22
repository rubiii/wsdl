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

RSpec.describe 'Yahoo\'s AccountService' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:yahoo] }
  let(:service_name) { :AccountServiceService }
  let(:port_name)    { :AccountService }

  before do
    service.start
  end

  it 'returns an advertiser account with nested types' do
    operation = client.operation(service_name, port_name, :addManagedAdvertiser)

    operation.prepare do
      header do
        tag('Security') do
          tag('UsernameToken') do
            tag('Username', 'apiuser')
            tag('Password', 'apipass')
          end
        end
        tag('license', 'LIC-001')
        tag('accountID', 'ACCT-001')
      end
      body do
        tag('addManagedAdvertiser') do
          tag('account') do
            tag('companyName', 'Acme Corp')
            tag('defaultCurrency', 'USD')
            tag('managedAccount', true)
          end
        end
      end
    end
    response = operation.invoke
    result = response.body[:addManagedAdvertiserResponse][:out]

    expect(result[:operationSucceeded]).to be true

    account = result[:account]
    expect(account[:ID]).to eq('ADV-12345')
    expect(account[:companyID]).to eq(67_890)
    expect(account[:companyName]).to eq('Acme Corp')
    expect(account[:managedAccount]).to be true
    expect(account[:yahooOwnedAndOperatedFlag]).to be false
    expect(account[:accountTypes][:AccountType]).to eq(['Advertiser'])
    expect(account[:address][:city]).to eq('Sunnyvale')
  end
end
