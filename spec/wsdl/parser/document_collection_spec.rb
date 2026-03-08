# frozen_string_literal: true

RSpec.describe WSDL::Parser::DocumentCollection do
  subject(:collection) { described_class.new }

  describe '#seal!' do
    it 'marks the collection as sealed and returns self' do
      expect(collection.sealed?).to be(false)
      expect(collection.seal!).to be(collection)
      expect(collection.sealed?).to be(true)
    end
  end

  describe '#<<' do
    let(:document) { instance_double(WSDL::Parser::Document) }

    it 'allows adding documents before sealing' do
      collection << document
      expect(collection.to_a).to eq([document])
    end

    it 'raises SealedCollectionError when adding after sealing' do
      collection.seal!

      expect {
        collection << document
      }.to raise_error(WSDL::SealedCollectionError, /collection is sealed/)
    end
  end
end
