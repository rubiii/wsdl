# frozen_string_literal: true

RSpec.describe 'Daisycon' do
  subject(:client) { WSDL::Client.new fixture('wsdl/daisycon') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'transactionService' => {
        ports: {
          'transactionPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://api.daisycon.com/advertiser/soap//transaction/',
            operations: [{ name: 'getTransactions' }, { name: 'validateTransaction' }]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operations = client.operations('transactionService', 'transactionPort')

    expect(operations).to include('getTransactions', 'validateTransaction')
  end

  it 'raises an error because RPC/encoded operations are not supported' do
    service = 'transactionService'
    port = 'transactionPort'

    expect { client.operation(service, port, 'getTransactions') }
      .to raise_error(WSDL::UnsupportedStyleError, %r{"getTransactions" is an "rpc/encoded" style operation})
  end
end
