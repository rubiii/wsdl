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

      expect(item[:attributes]).to eq([{ name: 'id', type: 'xsd:integer', required: true, list: false }])
    end

    it 'marks optional attributes correctly' do
      attr = build_attribute(name: 'lang', base_type: 'xsd:string', use: 'optional')
      element = build_element(name: 'Item', base_type: 'xsd:string', attributes: [attr])
      contract = described_class.new([element], section: :body)

      tree = contract.tree
      item = tree.find { |n| n[:name] == 'Item' }

      expect(item[:attributes]).to eq([{ name: 'lang', type: 'xsd:string', required: false, list: false }])
    end
  end

  describe 'kind metadata' do
    it 'marks simple type elements as :simple' do
      element = build_element(name: 'Count', base_type: 'xsd:int')
      contract = described_class.new([element], section: :body)

      expect(contract.paths.first[:kind]).to eq :simple
      expect(contract.tree.first[:kind]).to eq :simple
    end

    it 'marks complex type elements as :complex' do
      child = build_element(name: 'Name', base_type: 'xsd:string')
      element = build_element(name: 'User', children: [child])
      contract = described_class.new([element], section: :body)

      expect(contract.paths.first[:kind]).to eq :complex
      expect(contract.tree.first[:kind]).to eq :complex
    end

    it 'marks recursive type elements as :recursive' do
      element = WSDL::XML::Element.new
      element.name = 'Node'
      element.recursive_type = 'tns:TreeNode'

      contract = described_class.new([element], section: :body)

      expect(contract.paths.first[:kind]).to eq :recursive
      expect(contract.tree.first[:kind]).to eq :recursive
    end
  end

  describe 'list metadata' do
    it 'includes list: false for non-list simple type elements in tree' do
      element = build_element(name: 'Count', base_type: 'xsd:int')
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'Count' }

      expect(node[:list]).to be false
    end

    it 'includes list: true for list simple type elements in tree' do
      element = build_element(name: 'Tags', base_type: 'xsd:string')
      element.list = true
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'Tags' }

      expect(node[:list]).to be true
    end

    it 'omits list for complex type elements in tree' do
      child = build_element(name: 'Name', base_type: 'xsd:string')
      element = build_element(name: 'User', children: [child])
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'User' }

      expect(node).not_to have_key(:list)
    end
  end

  describe 'wildcard metadata' do
    it 'includes wildcard: false for non-wildcard complex type elements in tree' do
      child = build_element(name: 'Name', base_type: 'xsd:string')
      element = build_element(name: 'User', children: [child])
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'User' }

      expect(node[:wildcard]).to be false
    end

    it 'includes wildcard: true for wildcard complex type elements in tree' do
      child = build_element(name: 'Name', base_type: 'xsd:string')
      element = build_element(name: 'Container', children: [child], any_content: true)
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'Container' }

      expect(node[:wildcard]).to be true
    end

    it 'omits wildcard for simple type elements in tree' do
      element = build_element(name: 'Count', base_type: 'xsd:int')
      contract = described_class.new([element], section: :body)

      node = contract.tree.find { |n| n[:name] == 'Count' }

      expect(node).not_to have_key(:wildcard)
    end
  end

  describe 'paths and tree consistency' do
    it 'returns the same attribute metadata from both views' do
      attr = build_attribute(name: 'id', base_type: 'xsd:integer')
      element = build_element(name: 'Item', base_type: 'xsd:string', attributes: [attr])
      contract = described_class.new([element], section: :body)

      path_attrs = contract.paths.find { |p| p[:path] == %w[Item] }[:attributes]
      tree_attrs = contract.tree.find { |n| n[:name] == 'Item' }[:attributes]

      expect(path_attrs).to eq(tree_attrs)
    end

    it 'returns the same list metadata for simple type elements from both views' do
      element = build_element(name: 'Tags', base_type: 'xsd:string')
      element.list = true
      contract = described_class.new([element], section: :body)

      path_list = contract.paths.find { |p| p[:path] == %w[Tags] }[:list]
      tree_list = contract.tree.find { |n| n[:name] == 'Tags' }[:list]

      expect(path_list).to eq(tree_list)
      expect(path_list).to be true
    end

    it 'returns the same wildcard metadata for complex type elements from both views' do
      child = build_element(name: 'Name', base_type: 'xsd:string')
      element = build_element(name: 'Container', children: [child], any_content: true)
      contract = described_class.new([element], section: :body)

      path_wildcard = contract.paths.find { |p| p[:path] == %w[Container] }[:wildcard]
      tree_wildcard = contract.tree.find { |n| n[:name] == 'Container' }[:wildcard]

      expect(path_wildcard).to eq(tree_wildcard)
      expect(path_wildcard).to be true
    end
  end
end
