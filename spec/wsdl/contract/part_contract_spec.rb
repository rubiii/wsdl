# frozen_string_literal: true

RSpec.describe WSDL::Contract::PartContract do
  # rubocop:disable Metrics/ParameterLists
  def build_element(name:, base_type: nil, children: [], attributes: [],
                    any_content: false, min_occurs: '1')
    el = WSDL::XML::Element.new
    el.name = name
    el.base_type = base_type
    el.children = children
    el.any_content = any_content
    el.min_occurs = min_occurs
    el.attributes = attributes unless attributes.empty?
    el
  end
  # rubocop:enable Metrics/ParameterLists

  def build_attribute(name:, base_type: 'xsd:string', use: 'required')
    attr = WSDL::XML::Attribute.new
    attr.name = name
    attr.base_type = base_type
    attr.use = use
    attr
  end

  describe '#tree' do
    it 'includes attribute_tree for elements with attributes' do
      attr = build_attribute(name: 'id', base_type: 'xsd:integer')
      element = build_element(name: 'Item', base_type: 'xsd:string', attributes: [attr])
      contract = described_class.new([element], section: :body)

      tree = contract.tree
      item = tree.find { |n| n[:name] == 'Item' }

      expect(item[:attributes]).to eq([{ name: 'id', type: 'xsd:integer', required: true }])
    end

    it 'marks optional attributes correctly' do
      attr = build_attribute(name: 'lang', base_type: 'xsd:string', use: 'optional')
      element = build_element(name: 'Item', base_type: 'xsd:string', attributes: [attr])
      contract = described_class.new([element], section: :body)

      tree = contract.tree
      item = tree.find { |n| n[:name] == 'Item' }

      expect(item[:attributes]).to eq([{ name: 'lang', type: 'xsd:string', required: false }])
    end
  end
end
