# frozen_string_literal: true

require 'benchmark'

RSpec.describe 'Economic' do
  subject(:client) { WSDL::Client.new fixture('wsdl/economic') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'EconomicWebService' => {
        ports: {
          'EconomicWebServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.e-conomic.com/secure/api1/EconomicWebservice.asmx'
          },
          'EconomicWebServiceSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'https://api.e-conomic.com/secure/api1/EconomicWebservice.asmx'
          }
        }
      }
    )
  end

  it 'knows operations with Arrays' do
    service = 'EconomicWebService'
    port = 'EconomicWebServiceSoap'
    operation = client.operation(service, port, 'Account_GetDataArray')

    expect(operation.soap_action).to eq('http://e-conomic.com/Account_GetDataArray')
    expect(operation.endpoint).to eq('https://api.e-conomic.com/secure/api1/EconomicWebservice.asmx')

    namespace = 'http://e-conomic.com'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Account_GetDataArray'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Account_GetDataArray entityHandles],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Account_GetDataArray entityHandles AccountHandle],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[Account_GetDataArray entityHandles AccountHandle Number],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 's:int',
        list: false
}
    ])
  end

  it 'has an ok parse-time for huge wsdl files' do
    parse_time = Benchmark.realtime do
      client.operations('EconomicWebService', 'EconomicWebServiceSoap')
    end

    # this probably needs to be increased for CI
    # but it should prevent major performance problems.
    expect(parse_time).to be < 1.0
  end
end
