# frozen_string_literal: true

# PayPal multi-file WSDL acceptance test.
#
# This fixture surfaced the TypeCompactor KeyError bug in NamespaceCompactor.
# The PayPal WSDL imports three XSD files with circular cross-references
# across multiple namespaces:
#
#   - urn:ebay:api:PayPalAPI        (main WSDL)
#   - urn:ebay:apis:CoreComponentTypes
#   - urn:ebay:apis:eBLBaseComponents
#   - urn:ebay:apis:EnhancedDataTypes
#
# Parsing this fixture exercises cross-namespace type resolution and
# proves the NamespaceCompactor handles element-ref deduplication correctly.

RSpec.describe 'PayPal' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/paypal/manifest'), http_mock) }

  it 'parses without build issues' do
    expect(client.definition.build_issues).to be_empty
  end

  it 'returns a map of services and ports' do
    services = client.services

    expect(services.keys).to eq(['PayPalAPIInterfaceService'])
    expect(services['PayPalAPIInterfaceService'][:ports].keys).to contain_exactly('PayPalAPI', 'PayPalAPIAA')
  end

  it 'discovers 25 operations on the PayPalAPI port' do
    operations = client.operations('PayPalAPIInterfaceService', 'PayPalAPI')

    expect(operations.count).to eq(25)
    expect(operations).to include(
      'RefundTransaction',
      'GetTransactionDetails',
      'TransactionSearch',
      'MassPay',
      'AddressVerify',
      'GetBalance'
    )
  end

  it 'discovers 32 operations on the PayPalAPIAA port' do
    operations = client.operations('PayPalAPIInterfaceService', 'PayPalAPIAA')

    expect(operations.count).to eq(32)
    expect(operations).to include(
      'DoExpressCheckoutPayment',
      'SetExpressCheckout',
      'GetExpressCheckoutDetails',
      'DoDirectPayment',
      'DoCapture',
      'DoVoid',
      'DoAuthorization',
      'CreateRecurringPaymentsProfile'
    )
  end

  it 'resolves cross-namespace schema imports for AddressVerify' do
    operation = client.operation('PayPalAPIInterfaceService', 'PayPalAPI', 'AddressVerify')

    expect(operation.endpoint).to eq('https://api.sandbox.paypal.com/2.0/')

    expect(operation.contract.request.body.paths).to eq([
      { path: ['AddressVerifyReq'],
        kind: :complex,
        namespace: 'urn:ebay:api:PayPalAPI',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest],
        kind: :complex,
        namespace: 'urn:ebay:api:PayPalAPI',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: true },
      { path: %w[AddressVerifyReq AddressVerifyRequest DetailLevel],
        kind: :simple,
        namespace: 'urn:ebay:apis:eBLBaseComponents',
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        type: 'xs:token',
        list: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest ErrorLanguage],
        kind: :simple,
        namespace: 'urn:ebay:apis:eBLBaseComponents',
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest Version],
        kind: :simple,
        namespace: 'urn:ebay:apis:eBLBaseComponents',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest Email],
        kind: :simple,
        namespace: 'urn:ebay:api:PayPalAPI',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest Street],
        kind: :simple,
        namespace: 'urn:ebay:api:PayPalAPI',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false },
      { path: %w[AddressVerifyReq AddressVerifyRequest Zip],
        kind: :simple,
        namespace: 'urn:ebay:api:PayPalAPI',
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false }
    ])
  end

  it 'resolves cross-namespace elements for DoExpressCheckoutPayment on PayPalAPIAA' do
    operation = client.operation('PayPalAPIInterfaceService', 'PayPalAPIAA', 'DoExpressCheckoutPayment')

    expect(operation.endpoint).to eq('https://api-aa.sandbox.paypal.com/2.0/')

    paths = operation.contract.request.body.paths

    # Verify the top-level structure spans multiple namespaces
    namespaces = paths.map { |p| p[:namespace] }.uniq
    expect(namespaces).to include('urn:ebay:api:PayPalAPI', 'urn:ebay:apis:eBLBaseComponents')

    # Verify the deeply nested request details are resolved
    detail_paths = paths.select { |p| p[:path].include?('DoExpressCheckoutPaymentRequestDetails') }
    expect(detail_paths).not_to be_empty

    # Token is a required field inside the request details
    token = paths.find { |p|
      p[:path] == %w[DoExpressCheckoutPaymentReq DoExpressCheckoutPaymentRequest DoExpressCheckoutPaymentRequestDetails
                     Token]
    }
    expect(token).to include(
      kind: :simple,
      namespace: 'urn:ebay:apis:eBLBaseComponents',
      type: 'xs:string',
      min_occurs: '1'
    )
  end
end
