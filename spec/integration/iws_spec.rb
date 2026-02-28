# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with IWS' do
  subject(:client) { WSDL.new fixture('wsdl/iws') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'IWSIntegERPservice' => {
        ports: {
          'IWSIntegERPPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://177.75.152.221:8084/WSIntegERP/WSIntegERP.exe/soap/IWSIntegERP'
          }
        }
      }
    )
  end

  it 'raises an error because RPC/encoded operations are not' do
    service = 'IWSIntegERPservice'
    port = 'IWSIntegERPPort'

    expect { client.operation(service, port, 'Autenticacao') }
      .to raise_error(WSDL::UnsupportedStyleError, %r{"Autenticacao" is an "rpc/encoded" style operation})
  end
end
