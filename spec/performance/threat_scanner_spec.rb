# frozen_string_literal: true

require 'benchmark'

RSpec.describe 'ThreatScanner performance' do
  let(:large_xml) { File.read(fixture('wsdl/economic')).b }

  it 'scans the large WSDL within acceptable time', :timing do
    scanner = WSDL::XML::ThreatScanner.new(large_xml)

    scan_time = Benchmark.realtime { scanner.scan }

    expect(scan_time).to be < 0.25
  end

  it 'stays within allocation budget' do
    allocs = count_allocations {
      WSDL::XML::ThreatScanner.new(large_xml).scan
    }

    expect(allocs).to be < 5_000
  end
end
