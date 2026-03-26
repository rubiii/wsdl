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

RSpec.describe 'Marketo' do
  subject(:client) { WSDL::Client.new(WSDL.parse(service.wsdl_url)) }

  let(:service) { WSDL::TestService[:marketo] }
  let(:service_name) { :MktMktowsApiService }
  let(:port_name)    { :MktowsApiSoapPort }

  before do
    service.start
  end

  it 'returns campaigns with headers, arrays, and integer types' do
    operation = client.operation(service_name, port_name, :getCampaignsForSource)

    operation.prepare do
      header do
        tag('AuthenticationHeader') do
          tag('mktowsUserId', 'user_123')
          tag('requestSignature', 'sig_abc')
          tag('requestTimestamp', '2025-01-15T10:00:00Z')
          tag('audit', '')
          tag('mode', 1)
        end
      end
      body do
        tag('paramsGetCampaignsForSource') do
          tag('source', 'MKTOWS')
          tag('name', 'Welcome')
          tag('exactName', false)
        end
      end
    end
    response = operation.invoke
    result = response.body[:successGetCampaignsForSource][:result]

    expect(result[:returnCount]).to eq(2)

    campaigns = result[:campaignRecordList][:campaignRecord]
    expect(campaigns).to be_an(Array)
    expect(campaigns.size).to eq(2)
    expect(campaigns[0][:id]).to eq(1001)
    expect(campaigns[0][:name]).to eq('Welcome Email')
    expect(campaigns[1][:id]).to eq(1002)
  end

  it 'returns empty results for no matches' do
    operation = client.operation(service_name, port_name, :getCampaignsForSource)

    operation.prepare do
      header do
        tag('AuthenticationHeader') do
          tag('mktowsUserId', 'user_123')
          tag('requestSignature', 'sig_abc')
          tag('requestTimestamp', '2025-01-15T10:00:00Z')
          tag('audit', '')
          tag('mode', 1)
        end
      end
      body do
        tag('paramsGetCampaignsForSource') do
          tag('source', 'MKTOWS')
          tag('name', 'Nonexistent')
          tag('exactName', true)
        end
      end
    end
    response = operation.invoke
    result = response.body[:successGetCampaignsForSource][:result]

    expect(result[:returnCount]).to eq(0)
    expect(result[:campaignRecordList]).to eq({})
  end
end
