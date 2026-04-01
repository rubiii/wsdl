# frozen_string_literal: true

# FedEx Ship single-file WSDL acceptance test.
#
# This fixture surfaced the xs:time serialization bug where
# Response::Builder#serialize_value produced full dateTime strings
# for xs:time fields, breaking the roundtrip.
#
# The FedEx Ship WSDL has 6 xs:time fields across two operations
# (processTag and processShipment) in three complex types:
#
#   - CompletedTagDetail.CutoffTime
#   - CustomDeliveryWindowDetail.RequestTime
#   - ShipmentLegRateDetail.PublishedDeliveryTime

RSpec.describe 'FedEx Ship' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/fedex_ship')) }

  it 'parses without build issues' do
    expect(client.definition.build_issues).to be_empty
  end

  it 'discovers the ShipService service with one port' do
    services = client.services

    expect(services.keys).to eq(['ShipService'])
    expect(services['ShipService'][:ports].keys).to eq(['ShipServicePort'])
  end

  it 'discovers 5 operations on ShipServicePort' do
    operations = client.operations('ShipService', 'ShipServicePort')

    expect(operations.count).to eq(5)
    expect(operations).to contain_exactly(
      'processTag',
      'processShipment',
      'deleteTag',
      'deleteShipment',
      'validateShipment'
    )
  end

  it 'exposes the processShipment operation with the correct endpoint' do
    operation = client.operation('ShipService', 'ShipServicePort', 'processShipment')

    expect(operation.soap_action).to eq('http://fedex.com/ws/ship/v17/processShipment')
    expect(operation.endpoint).to eq('https://ws.fedex.com:443/web-services/ship')
  end

  it 'exposes the processTag operation with the correct endpoint' do
    operation = client.operation('ShipService', 'ShipServicePort', 'processTag')

    expect(operation.soap_action).to eq('http://fedex.com/ws/ship/v17/processTag')
    expect(operation.endpoint).to eq('https://ws.fedex.com:443/web-services/ship')
  end

  it 'includes xs:time fields in the processShipment request contract' do
    operation = client.operation('ShipService', 'ShipServicePort', 'processShipment')
    paths = operation.contract.request.body.paths

    # CustomDeliveryWindowDetail.RequestTime is nested inside
    # ProcessShipmentRequest > RequestedShipment > SpecialServicesRequested > CustomDeliveryWindowDetail
    request_time = paths.find { |p| p[:path].last == 'RequestTime' }

    expect(request_time).not_to be_nil
    expect(request_time[:type]).to eq('xs:time')
    expect(request_time[:kind]).to eq(:simple)
  end

  it 'includes xs:time fields in the processTag request contract' do
    operation = client.operation('ShipService', 'ShipServicePort', 'processTag')
    paths = operation.contract.request.body.paths

    # Same CustomDeliveryWindowDetail.RequestTime path through ProcessTagRequest
    request_time = paths.find { |p| p[:path].last == 'RequestTime' }

    expect(request_time).not_to be_nil
    expect(request_time[:type]).to eq('xs:time')
    expect(request_time[:kind]).to eq(:simple)
  end
end
