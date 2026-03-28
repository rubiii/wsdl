# frozen_string_literal: true

require 'benchmark'

# rubocop:disable RSpec/InstanceVariable -- before(:all) requires ivars for expensive shared setup
RSpec.describe 'Schema::Node performance' do
  describe 'traversal' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      parsed = SpecSupport::ParsedFixture.new('wsdl/economic')
      @complex_type = parsed.find_complex_type_with_children
    end

    it 'traverses elements within acceptable time', :timing do
      skip 'No complex type with children found in fixture' unless @complex_type

      traverse_time = Benchmark.realtime do
        @complex_type.elements([], limits: WSDL::Limits.new)
      end

      expect(traverse_time).to be < 0.01
    end

    it 'memoizes element traversal results' do
      skip 'No complex type with children found in fixture' unless @complex_type

      # First call populates the cache
      @complex_type.elements([], limits: WSDL::Limits.new)

      # Second call should produce zero allocations from the traversal
      allocs = count_allocations {
        @complex_type.elements([], limits: WSDL::Limits.new)
      }

      # Only the memo array and concat — no re-traversal allocations
      expect(allocs).to be < 5
    end
  end

  describe 'release_dom_references!' do
    before(:all) do # rubocop:disable RSpec/BeforeAfterAll
      @parsed = SpecSupport::ParsedFixture.new('wsdl/economic')
    end

    it 'releases DOM references with near-zero allocations' do
      allocs = count_allocations {
        @parsed.schemas.release_dom_references!
      }

      # Only iterator overhead — no new objects from setting ivars to nil
      expect(allocs).to be < 20
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
