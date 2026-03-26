# frozen_string_literal: true

RSpec.describe 'IWS' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/iws')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'IWSIntegERPservice' => {
        ports: {
          'IWSIntegERPPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://177.75.152.221:8084/WSIntegERP/WSIntegERP.exe/soap/IWSIntegERP',
            operations: [
              { name: 'Autenticacao' },
              { name: 'InsereTrajeto' },
              { name: 'InsereEntidade' },
              { name: 'InsereTrajetoXml' },
              { name: 'InsereEntidadeXml' },
              { name: 'InsereUsuarioXml' },
              { name: 'AtualizaTrajeto' },
              { name: 'FinalizaTrajeto' },
              { name: 'AtualizaTrajeto_Entidade' },
              { name: 'BuscaTrajeto' },
              { name: 'BuscaLocalizacao' },
              { name: 'ReprogramarPonto' },
              { name: 'BuscaNCTrajeto' },
              { name: 'BuscaNCTrajeto2' },
              { name: 'BuscaTrajetoAtributo' },
              { name: 'InsereAlerta' }
            ]
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
