# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Taxcloud' do
  subject(:client) { WSDL::Client.new fixture('wsdl/taxcloud') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'TaxCloud' => {
        ports: {
          'TaxCloudSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.taxcloud.net/1.0/TaxCloud.asmx'
          },
          'TaxCloudSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'https://api.taxcloud.net/1.0/TaxCloud.asmx'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'TaxCloud'
    port = 'TaxCloudSoap'
    operation = client.operation(service, port, 'VerifyAddress')

    expect(operation.soap_action).to eq('http://taxcloud.net/VerifyAddress')
    expect(operation.endpoint).to eq('https://api.taxcloud.net/1.0/TaxCloud.asmx')

    namespace = 'http://taxcloud.net'

    expect(operation.body_parts).to eq([
      [['VerifyAddress'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[VerifyAddress uspsUserID],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress address1],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress address2],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress city],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress state],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress zip5],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 's:string'
}
],
      [%w[VerifyAddress zip4],
       { namespace: namespace, form: 'qualified', singular: true, type: 's:string' }
]
    ])
  end
end
