# frozen_string_literal: true

RSpec.describe 'AWSE' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/awse')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AWSECommerceService' => {
        ports: {
          'AWSECommerceServicePort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.com/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortCA' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.ca/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortCN' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.cn/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortDE' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.de/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortFR' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.fr/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortIT' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.it/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortJP' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.co.jp/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortUK' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.co.uk/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
          },
          'AWSECommerceServicePortUS' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://webservices.amazon.com/onca/soap?Service=AWSECommerceService',
            operations: [
              { name: 'ItemSearch' },
              { name: 'ItemLookup' },
              { name: 'BrowseNodeLookup' },
              { name: 'SimilarityLookup' },
              { name: 'CartGet' },
              { name: 'CartCreate' },
              { name: 'CartAdd' },
              { name: 'CartModify' },
              { name: 'CartClear' }
            ]
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

    expect(operation.contract.request.body.paths).to eq([
      { path: ['CartAdd'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[CartAdd MarketplaceDomain],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd AWSAccessKeyId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd AssociateTag],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Validate],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd XMLEscaping],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[CartAdd Shared CartId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared HMAC],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared MergeCart],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared Items],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[CartAdd Shared Items Item],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[CartAdd Shared Items Item ASIN],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared Items Item OfferListingId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared Items Item Quantity],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:positiveInteger',
        list: false
},
      { path: %w[CartAdd Shared Items Item AssociateTag],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared Items Item ListItemId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Shared ResponseGroup],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[CartAdd Request CartId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request HMAC],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request MergeCart],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request Items],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[CartAdd Request Items Item],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[CartAdd Request Items Item ASIN],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request Items Item OfferListingId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request Items Item Quantity],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:positiveInteger',
        list: false
},
      { path: %w[CartAdd Request Items Item AssociateTag],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request Items Item ListItemId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[CartAdd Request ResponseGroup],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        type: 'xs:string',
        list: false
}
    ])
  end
end
