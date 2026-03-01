# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Atlassian Jira' do
  subject(:client) { WSDL::Client.new fixture('wsdl/jira') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'JiraSoapServiceService' => {
        ports: {
          'jirasoapservice-v2' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://jira.atlassian.com/rpc/soap/jirasoapservice-v2'
          }
        }
      }
    )
  end

  it 'raises an error because RPC/encoded operations are not' do
    service = 'JiraSoapServiceService'
    port = 'jirasoapservice-v2'

    expect { client.operation(service, port, 'updateGroup') }
      .to raise_error(WSDL::UnsupportedStyleError, %r{"updateGroup" is an "rpc/encoded" style operation})
  end
end
