# frozen_string_literal: true

require 'benchmark'

RSpec.describe 'Parse pipeline performance' do
  let(:large_wsdl) { fixture('wsdl/economic') }
  let(:small_wsdl) { fixture('wsdl/blz_service') }

  describe 'large WSDL (economic, 65k lines)' do
    it 'parses within acceptable time', :timing do
      parse_time = Benchmark.realtime { WSDL::Parser.parse(large_wsdl, http_mock) }

      expect(parse_time).to be < 2.0
    end

    it 'stays within allocation budget' do
      allocs = count_allocations { WSDL::Parser.parse(large_wsdl, http_mock) }

      expect(allocs).to be < 1_000_000
    end
  end

  describe 'small WSDL (blz_service, 88 lines)' do
    it 'parses within acceptable time', :timing do
      parse_time = Benchmark.realtime { WSDL::Parser.parse(small_wsdl, http_mock) }

      expect(parse_time).to be < 0.5
    end

    it 'stays within allocation budget' do
      allocs = count_allocations { WSDL::Parser.parse(small_wsdl, http_mock) }

      expect(allocs).to be < 50_000
    end
  end
end
