# frozen_string_literal: true

WSDL::TestService.define(:marketo, wsdl: 'wsdl/marketo') do
  operation :getCampaignsForSource do
    on source: 'MKTOWS', name: 'Welcome' do
      {
        result: {
          returnCount: 2,
          campaignRecordList: {
            campaignRecord: [
              { id: 1001, name: 'Welcome Email', description: 'Sends welcome email to new leads' },
              { id: 1002, name: 'Welcome Series', description: 'Multi-step onboarding campaign' }
            ]
          }
        }
      }
    end

    on source: 'MKTOWS', name: 'Nonexistent', exactName: true do
      {
        result: {
          returnCount: 0,
          campaignRecordList: {}
        }
      }
    end
  end
end
