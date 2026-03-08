# frozen_string_literal: true

RSpec.describe WSDL::XML::Element do
  describe '#attributes' do
    subject(:element) { described_class.new }

    it 'defaults to an empty frozen array' do
      expect(element.attributes).to eq([])
      expect(element.attributes).to be_frozen
    end

    it 'accepts an array of XML::Attribute objects' do
      attribute = WSDL::XML::Attribute.new
      attribute.name = 'id'
      attrs = [attribute]

      element.attributes = attrs

      expect(element.attributes).to eq([attribute])
      expect(element.attributes).not_to be(attrs)
      expect(element.attributes).to be_frozen
    end

    it 'normalizes nil to an empty frozen array' do
      element.attributes = nil

      expect(element.attributes).to eq([])
      expect(element.attributes).to be_frozen
    end

    it 'raises when value is not an array' do
      expect {
        element.attributes = { id: '123' }
      }.to raise_error(TypeError, /Array<WSDL::XML::Attribute>/)
    end

    it 'raises when array includes non-Attribute objects' do
      expect {
        element.attributes = ['id']
      }.to raise_error(TypeError, /Array<WSDL::XML::Attribute>/)
    end
  end
end
