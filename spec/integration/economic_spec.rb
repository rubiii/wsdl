# frozen_string_literal: true

require 'spec_helper'
require 'benchmark'

RSpec.describe 'Integration with Economic' do
  before :all do
    @client = WSDL::Client.new fixture('wsdl/economic')
  end

  it 'returns a map of services and ports' do
    expect(@client.services).to eq(
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
    operation = @client.operation(service, port, 'Account_GetDataArray')

    expect(operation.soap_action).to eq('http://e-conomic.com/Account_GetDataArray')
    expect(operation.endpoint).to eq('https://api.e-conomic.com/secure/api1/EconomicWebservice.asmx')

    namespace = 'http://e-conomic.com'

    expect(request_body_paths(operation)).to eq([
      [['Account_GetDataArray'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Account_GetDataArray entityHandles],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Account_GetDataArray entityHandles AccountHandle],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[Account_GetDataArray entityHandles AccountHandle Number],
       { namespace: namespace, form: 'qualified', type: 's:int', singular: true }
]
    ])
  end

  it 'has an ok parse-time for huge wsdl files' do
    # profiler = MethodProfiler.observe(Wasabi::Parser)
    parse_time = Benchmark.realtime do
      @client.operations('EconomicWebService', 'EconomicWebServiceSoap')
    end
    # puts profiler.report

    # this probably needs to be increased for CI
    # but it should prevent major performance problems.
    expect(parse_time).to be < 1.0
  end
end
