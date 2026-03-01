# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with AWSE' do
  subject(:client) { WSDL::Client.new fixture('wsdl/awse') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AWSECommerceService' => {
        ports: {
          'AWSECommerceServicePort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.com/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortCA' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.ca/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortCN' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.cn/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortDE' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.de/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortFR' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.fr/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortIT' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.it/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortJP' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.co.jp/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortUK' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.co.uk/onca/soap?Service=AWSECommerceService'
          },
          'AWSECommerceServicePortUS' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.com/onca/soap?Service=AWSECommerceService'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'AWSECommerceService'
    port = 'AWSECommerceServicePort'
    operation = client.operation(service, port, 'CartAdd')

    expect(operation.soap_action).to eq('http://soap.amazon.com/CartAdd')
    expect(operation.endpoint).to eq('https://webservices.amazon.com/onca/soap?Service=AWSECommerceService')

    namespace = 'http://webservices.amazon.com/AWSECommerceService/2011-08-01'

    expect(operation.body_parts).to eq([
      [['CartAdd'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[CartAdd MarketplaceDomain],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd AWSAccessKeyId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd AssociateTag],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Validate],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd XMLEscaping],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[CartAdd Shared CartId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared HMAC],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared MergeCart],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared Items],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[CartAdd Shared Items Item],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[CartAdd Shared Items Item ASIN],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared Items Item OfferListingId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared Items Item Quantity],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:positiveInteger'
 }
],
      [%w[CartAdd Shared Items Item AssociateTag],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared Items Item ListItemId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Shared ResponseGroup],
       { namespace: namespace, form: 'qualified', singular: false,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[CartAdd Request CartId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request HMAC],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request MergeCart],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request Items],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[CartAdd Request Items Item],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[CartAdd Request Items Item ASIN],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request Items Item OfferListingId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request Items Item Quantity],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:positiveInteger'
 }
],
      [%w[CartAdd Request Items Item AssociateTag],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request Items Item ListItemId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[CartAdd Request ResponseGroup],
       { namespace: namespace, form: 'qualified', singular: false,
         type: 'xs:string'
 }
]
    ])
  end
end
