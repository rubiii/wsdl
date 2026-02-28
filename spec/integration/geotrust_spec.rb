require 'spec_helper'

describe 'Integration with Geotrust' do

  subject(:client) { Sekken.new fixture('wsdl/geotrust') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'query' => {
        ports: {
          'querySoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://test-api.geotrust.com:443/webtrust/query.jws'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operations = client.operations('query', 'querySoap')
    expect(operations).to match_array(['GetQuickApproverList', 'hello'])
  end

  it 'creates an operation with the correct endpoint' do
    operation = client.operation('query', 'querySoap', 'GetQuickApproverList')
    expect(operation.endpoint).to eq('https://test-api.geotrust.com:443/webtrust/query.jws')
  end

  it 'creates an example body' do
    operation = client.operation('query', 'querySoap', 'GetQuickApproverList')

    expect(operation.example_body).to eq(
      GetQuickApproverList: {
        Request: {
          QueryRequestHeader: {
            PartnerCode: 'string',
            AuthToken: {
              UserName: 'string',
              Password: 'string'
            },
            ReplayToken: 'string',
            UseReplayToken: 'boolean'
          },
          Domain: 'string',
          IncludeUserAgreement: {
            UserAgreementProductCode: 'string'
          }
        }
      }
    )
  end

end