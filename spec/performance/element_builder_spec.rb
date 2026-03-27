# frozen_string_literal: true

require 'benchmark'

# rubocop:disable RSpec/InstanceVariable -- before(:all) requires ivars for expensive shared setup
RSpec.describe 'ElementBuilder performance' do
  # Parse the WSDL once to extract schemas and document collection.
  # The resolver + import phase is not what we're measuring here.
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    @parsed = SpecSupport::ParsedFixture.new('wsdl/economic')
  end

  it 'builds all operations within acceptable time', :timing do
    build_time = Benchmark.realtime do
      WSDL::Definition::Builder.new(
        documents: @parsed.documents, schemas: @parsed.schemas,
        limits: WSDL::Limits.new,
        provenance: @parsed.provenance,
        schema_import_errors: @parsed.schema_import_errors
      ).build
    end

    expect(build_time).to be < 1.0
  end

  it 'stays within allocation budget' do
    allocs = count_allocations {
      WSDL::Definition::Builder.new(
        documents: @parsed.documents, schemas: @parsed.schemas,
        limits: WSDL::Limits.new,
        provenance: @parsed.provenance,
        schema_import_errors: @parsed.schema_import_errors
      ).build
    }

    expect(allocs).to be < 900_000
  end
end
# rubocop:enable RSpec/InstanceVariable
