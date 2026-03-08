# frozen_string_literal: true

RSpec.describe WSDL::Contract::MessageContract do
  def build_element(name:, base_type: nil, children: [])
    el = WSDL::XML::Element.new
    el.name = name
    el.base_type = base_type
    el.children = children
    el
  end

  def build_part(*elements)
    WSDL::Contract::PartContract.new(elements, section: :body)
  end

  describe '#header' do
    it 'returns the header part contract' do
      header = build_part(build_element(name: 'AuthHeader', base_type: 'xsd:string'))
      body = build_part
      contract = described_class.new(header:, body:)

      expect(contract.header).to equal(header)
    end
  end

  describe '#body' do
    it 'returns the body part contract' do
      header = build_part
      body = build_part(build_element(name: 'GetPrice', base_type: 'xsd:string'))
      contract = described_class.new(header:, body:)

      expect(contract.body).to equal(body)
    end
  end

  describe '#empty?' do
    it 'returns true when both header and body have no elements' do
      contract = described_class.new(header: build_part, body: build_part)
      expect(contract).to be_empty
    end

    it 'returns false when header has elements' do
      header = build_part(build_element(name: 'AuthHeader', base_type: 'xsd:string'))
      contract = described_class.new(header:, body: build_part)
      expect(contract).not_to be_empty
    end

    it 'returns false when body has elements' do
      body = build_part(build_element(name: 'GetPrice', base_type: 'xsd:string'))
      contract = described_class.new(header: build_part, body:)
      expect(contract).not_to be_empty
    end

    it 'returns false when both have elements' do
      header = build_part(build_element(name: 'AuthHeader', base_type: 'xsd:string'))
      body = build_part(build_element(name: 'GetPrice', base_type: 'xsd:string'))
      contract = described_class.new(header:, body:)
      expect(contract).not_to be_empty
    end
  end

  describe 'immutability' do
    it 'is frozen' do
      contract = described_class.new(header: build_part, body: build_part)
      expect(contract).to be_frozen
    end
  end
end
