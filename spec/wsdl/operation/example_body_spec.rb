# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Operation do
  let(:add_logins) do
    client = WSDL::Client.new fixture('wsdl/bronto')

    service_name = :BrontoSoapApiImplService
    port_name    = :BrontoSoapApiImplPort

    client.operation(service_name, port_name, :addLogins)
  end

  let(:get_mu_bets_lite) do
    client = WSDL::Client.new fixture('wsdl/betfair')

    service_name = port_name = :BFExchangeService
    client.operation(service_name, port_name, :getMUBetsLite)
  end

  describe '#example_body' do
    it 'returns an Array with a single Hash for Arrays of complex types' do
      expect(request_template(add_logins, section: :body)).to eq(
        addLogins: {

          # array of complex types
          accounts: [
            {
              username: 'string',
              password: 'string',
              contactInformation: {
                organization: 'string',
                firstName: 'string',
                lastName: 'string',
                email: 'string',
                phone: 'string',
                address: 'string',
                address2: 'string',
                city: 'string',
                state: 'string',
                zip: 'string',
                country: 'string',
                notes: 'string'
              },
              permissionAgencyAdmin: 'boolean',
              permissionAdmin: 'boolean',
              permissionApi: 'boolean',
              permissionUpgrade: 'boolean',
              permissionFatigueOverride: 'boolean',
              permissionMessageCompose: 'boolean',
              permissionMessageApprove: 'boolean',
              permissionMessageDelete: 'boolean',
              permissionAutomatorCompose: 'boolean',
              permissionListCreateSend: 'boolean',
              permissionListCreate: 'boolean',
              permissionSegmentCreate: 'boolean',
              permissionFieldCreate: 'boolean',
              permissionFieldReorder: 'boolean',
              permissionSubscriberCreate: 'boolean',
              permissionSubscriberView: 'boolean'
            }
          ]
        }
      )
    end

    it 'returns an Array with a single simple type for Arrays of simple types' do
      expect(request_template(get_mu_bets_lite, section: :body)).to eq(
        getMUBetsLite: {
          request: {
            header: {
              clientStamp: 'long',
              sessionToken: 'string'
            },
            betStatus: 'string',
            marketId: 'int',
            betIds: {

              # array of simple types
              betId: ['long']

            },
            orderBy: 'string',
            sortOrder: 'string',
            recordCount: 'int',
            startRecord: 'int',
            matchedSince: 'dateTime',
            excludeLastSecond: 'boolean'
          }
        }
      )
    end
  end
end
