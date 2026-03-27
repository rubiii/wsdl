# frozen_string_literal: true

require 'benchmark'

# rubocop:disable RSpec/InstanceVariable -- before(:all) requires ivars for expensive shared setup
RSpec.describe 'Request::Serializer performance' do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    wsdl_path = SpecSupport::Fixture.path('wsdl/blz_service')
    http = SpecSupport::HTTPMock.new
    definition = WSDL.parse(wsdl_path, http:)
    @client = WSDL::Client.new(definition, http:)

    service, info = @client.services.first
    port = info[:ports].keys.first
    @service = service
    @port = port
    @op_name = @client.operations(service, port).first
  end

  def build_prepared_operation
    op = @client.operation(@service, @port, @op_name)
    op.prepare do
      body do
        tag('getBank') { tag('blz', '70070010') }
      end
    end
    op
  end

  it 'serializes a request within acceptable time', :timing do
    op = build_prepared_operation

    serialize_time = Benchmark.realtime { op.to_xml }

    expect(serialize_time).to be < 0.01
  end

  it 'stays within allocation budget' do
    op = build_prepared_operation

    allocs = count_allocations { op.to_xml }

    expect(allocs).to be < 5_000
  end
end
# rubocop:enable RSpec/InstanceVariable
