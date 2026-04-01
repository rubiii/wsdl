# frozen_string_literal: true

RSpec.describe 'Taxcloud' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/taxcloud')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'TaxCloud' => {
        ports: {
          'TaxCloudSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.taxcloud.net/1.0/TaxCloud.asmx',
            operations: [
              { name: 'VerifyAddress' },
              { name: 'LookupForDate' },
              { name: 'Lookup' },
              { name: 'Authorized' },
              { name: 'AuthorizedWithCapture' },
              { name: 'Captured' },
              { name: 'Returned' },
              { name: 'GetTICGroups' },
              { name: 'GetTICs' },
              { name: 'GetTICsByGroup' },
              { name: 'AddExemptCertificate' },
              { name: 'DeleteExemptCertificate' },
              { name: 'GetExemptCertificates' }
            ]
          },
          'TaxCloudSoap12' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
            location: 'https://api.taxcloud.net/1.0/TaxCloud.asmx',
            operations: [
              { name: 'VerifyAddress' },
              { name: 'LookupForDate' },
              { name: 'Lookup' },
              { name: 'Authorized' },
              { name: 'AuthorizedWithCapture' },
              { name: 'Captured' },
              { name: 'Returned' },
              { name: 'GetTICGroups' },
              { name: 'GetTICs' },
              { name: 'GetTICsByGroup' },
              { name: 'AddExemptCertificate' },
              { name: 'DeleteExemptCertificate' },
              { name: 'GetExemptCertificates' }
            ]
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

    expect(operation.contract.request.body.paths).to eq([
      { path: ['VerifyAddress'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false },
      { path: %w[VerifyAddress uspsUserID],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress address1],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress address2],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress city],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress state],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress zip5],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false },
      { path: %w[VerifyAddress zip4],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 's:string',
        list: false }
    ])
  end
end
