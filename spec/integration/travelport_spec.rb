# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Travelport' do
  subject(:client) { WSDL.new(wsdl_path, http: http_mock) }

  # Using local file paths to test relative path resolution (Issue #5)
  let(:wsdl_path) { fixture('wsdl/travelport/system_v32_0/System.wsdl') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'ExternalCacheAccessService' => {
        ports: {
          'ExternalCacheAccessPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://localhost:8080/kestrel/ExternalCacheAccessService'
          }
        }
      },
      'SystemService' => {
        ports: {
          'SystemPingPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://localhost:8080/kestrel/SystemService'
          },
          'SystemInfoPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://localhost:8080/kestrel/SystemService'
          },
          'SystemtimePort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://localhost:8080/kestrel/SystemService'
          }
        }
      }
    )
  end

  it 'resolves relative WSDL imports to get the operations' do
    operations = client.operations('SystemService', 'SystemPingPort')

    expect(operations).to be_an(Array)
    expect(operations).to eq(['service'])
  end

  # This test verifies Issue #5 (relative URL imports) and Issue #17 (xsd:include support)
  # The chain is:
  #   System.wsdl imports SystemAbstract.wsdl (relative)
  #   SystemAbstract.wsdl includes System.xsd (relative)
  #   System.xsd imports ../common_v32_0/CommonReqRsp.xsd (relative)
  #   CommonReqRsp.xsd includes Common.xsd (relative)
  #
  # The PingReq type extends common:BaseReq which is defined in CommonReqRsp.xsd
  # BaseReq references elements like BillingPointOfSaleInfo from Common.xsd (via include)
  it 'resolves XSD includes and relative imports to get all type definitions' do
    ping_operation = client.operation('SystemService', 'SystemPingPort', 'service')

    # The operation should be able to resolve the body parts
    # This will fail if includes or relative imports aren't working
    body_parts = ping_operation.body_parts

    expect(body_parts).to be_an(Array)
    expect(body_parts).not_to be_empty

    # The first element should be PingReq
    expect(body_parts.first.first).to eq(['PingReq'])

    # Should include elements from Common.xsd (loaded via include)
    # BillingPointOfSaleInfo is defined in Common.xsd and referenced in BaseReq
    element_paths = body_parts.map(&:first)
    expect(element_paths).to include(%w[PingReq BillingPointOfSaleInfo])
  end

  it 'can generate an example body for the ping operation' do
    ping_operation = client.operation('SystemService', 'SystemPingPort', 'service')

    # This should not raise an error about missing types
    example = ping_operation.example_body

    expect(example).to be_a(Hash)
    expect(example).to have_key(:PingReq)
  end
end
