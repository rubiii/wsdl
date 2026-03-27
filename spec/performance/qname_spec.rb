# frozen_string_literal: true

RSpec.describe 'QName resolution performance' do
  let(:namespaces) do
    {
      'xmlns:tns' => 'http://example.com/target',
      'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:s' => 'http://www.w3.org/2001/XMLSchema',
      'xmlns:wsdl' => 'http://schemas.xmlsoap.org/wsdl/',
      'xmlns:soap' => 'http://schemas.xmlsoap.org/wsdl/soap/'
    }.freeze
  end

  let(:qnames) { %w[tns:MyElement xs:string s:int wsdl:part soap:body tns:Another] }

  before do
    WSDL::QName.clear_resolve_cache
  end

  it 'cold-cache resolution stays within allocation budget' do
    allocs = count_allocations {
      qnames.each { |qn| WSDL::QName.resolve(qn, namespaces:) }
    }

    # Each unique QName needs one frozen Array + string slicing.
    # Budget: at most 10 allocations per QName.
    expect(allocs).to be < qnames.size * 10
  end

  it 'warm-cache resolution produces zero new allocations' do
    # Warm the cache
    qnames.each do |qn|
      WSDL::QName.resolve(qn, namespaces:)
    end

    allocs = count_allocations {
      1000.times { qnames.each { |qn| WSDL::QName.resolve(qn, namespaces:) } }
    }

    # Allow a tiny tolerance for internal Ruby bookkeeping (Range, etc.)
    # but no per-lookup allocations.
    expect(allocs).to be <= 2
  end

  it 'caches per namespace scope identity' do
    other_namespaces = namespaces.dup.freeze

    # Resolve with first scope
    qnames.each do |qn|
      WSDL::QName.resolve(qn, namespaces:)
    end

    # Different object identity = separate cache scope, new allocations
    allocs = count_allocations {
      qnames.each { |qn| WSDL::QName.resolve(qn, namespaces: other_namespaces) }
    }

    expect(allocs).to be > 0
  end
end
