# frozen_string_literal: true

RSpec.describe WSDL::Definition::NamespaceTable do
  subject(:table) { described_class.new(['http://example.com', 'http://soap/']) }

  describe '#resolve' do
    it 'returns the URI for a valid index' do
      expect(table.resolve(0)).to eq('http://example.com')
      expect(table.resolve(1)).to eq('http://soap/')
    end

    it 'raises KeyError for an out-of-range index' do
      expect { table.resolve(99) }.to raise_error(KeyError, /namespace index 99 not found/)
    end
  end

  describe '#to_a' do
    it 'returns the underlying URI array' do
      expect(table.to_a).to eq(['http://example.com', 'http://soap/'])
    end
  end

  it 'is frozen' do
    expect(table).to be_frozen
  end
end
