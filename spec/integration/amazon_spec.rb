# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Amazon' do
  subject(:client) { WSDL.new fixture('wsdl/amazon') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AmazonFPS' => {
        ports: {
          'AmazonFPSPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fps.amazonaws.com'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'AmazonFPS'
    port = 'AmazonFPSPort'
    operation = client.operation(service, port, 'Pay')

    expect(operation.soap_action).to eq('Pay')
    expect(operation.endpoint).to eq('https://fps.amazonaws.com')

    namespace = 'http://fps.amazonaws.com/doc/2008-09-17/'

    expect(operation.body_parts).to eq([
      [['Pay'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay SenderTokenId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay RecipientTokenId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionAmount],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay TransactionAmount CurrencyCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionAmount Value],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay ChargeFeeTo],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay CallerReference],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay CallerDescription],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay SenderDescription],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay DescriptorPolicy],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay DescriptorPolicy SoftDescriptorType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay DescriptorPolicy CSOwner],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionTimeoutInMins],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:integer'
 }
],
      [%w[Pay MarketplaceFixedFee],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay MarketplaceFixedFee CurrencyCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay MarketplaceFixedFee Value],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay MarketplaceVariableFee],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:decimal'
 }
]
    ])
  end
end
