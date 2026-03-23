# frozen_string_literal: true

RSpec.describe WSDL::XML::Element do
  def build_attribute(name: 'id', base_type: 'xsd:string', use: 'optional', list: false)
    attr = WSDL::XML::Attribute.new
    attr.name = name
    attr.base_type = base_type
    attr.use = use
    attr.list = list
    attr
  end

  def build_element(name: 'user', namespace: 'http://example.com', form: 'qualified', **overrides)
    el = described_class.new
    el.name = name
    el.namespace = namespace
    el.form = form
    overrides.each do |key, value|
      el.public_send(:"#{key}=", value)
    end
    el
  end

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

  describe '#to_definition_h' do
    it 'converts a simple element to a hash' do
      element = build_element(base_type: 'xsd:string')

      expect(element.to_definition_h).to eq({
        name: 'user',
        namespace: 'http://example.com',
        form: 'qualified',
        type: 'simple',
        xsd_type: 'xsd:string',
        min_occurs: 1,
        max_occurs: 1,
        nillable: false,
        singular: true,
        list: false,
        any_content: false,
        recursive_type: nil,
        complex_type_id: nil,
        children: [],
        attributes: []
      })
    end

    it 'converts a complex element with children' do
      child = build_element(name: 'name', namespace: nil, form: 'unqualified', base_type: 'xsd:string')
      parent = build_element(name: 'user')
      parent.children = [child]

      hash = parent.to_definition_h
      expect(hash[:type]).to eq('complex')
      expect(hash[:xsd_type]).to be_nil
      expect(hash[:children].size).to eq(1)
      expect(hash[:children].first[:name]).to eq('name')
      expect(hash[:children].first[:type]).to eq('simple')
    end

    it 'converts a recursive element' do
      element = build_element(name: 'parent', recursive_type: 'ParentType')

      hash = element.to_definition_h
      expect(hash[:type]).to eq('recursive')
      expect(hash[:recursive_type]).to eq('ParentType')
    end

    it 'converts min_occurs and max_occurs to integers' do
      element = build_element(min_occurs: '0', max_occurs: '5')

      hash = element.to_definition_h
      expect(hash[:min_occurs]).to eq(0)
      expect(hash[:max_occurs]).to eq(5)
    end

    it 'converts unbounded max_occurs to Float::INFINITY' do
      element = build_element(max_occurs: 'unbounded', singular: false)

      expect(element.to_definition_h[:max_occurs]).to eq(Float::INFINITY)
    end

    it 'includes attributes' do
      attr = build_attribute(name: 'id', base_type: 'xsd:int', use: 'required')
      element = build_element(attributes: [attr])

      attrs = element.to_definition_h[:attributes]
      expect(attrs).to eq([{ name: 'id', base_type: 'xsd:int', use: 'required', list: false }])
    end

    it 'includes nillable and list flags' do
      element = build_element(base_type: 'xsd:string', nillable: true, list: true)

      hash = element.to_definition_h
      expect(hash[:nillable]).to be true
      expect(hash[:list]).to be true
    end

    it 'includes any_content flag' do
      element = build_element(any_content: true)

      expect(element.to_definition_h[:any_content]).to be true
    end

    it 'includes complex_type_id' do
      element = build_element(complex_type_id: 'http://example.com:UserType')

      expect(element.to_definition_h[:complex_type_id]).to eq('http://example.com:UserType')
    end

    it 'recursively converts deeply nested trees' do
      leaf = build_element(name: 'value', namespace: nil, form: 'unqualified', base_type: 'xsd:string')
      mid = build_element(name: 'item', namespace: nil, form: 'unqualified')
      mid.children = [leaf]
      root = build_element(name: 'items')
      root.children = [mid]

      hash = root.to_definition_h
      expect(hash[:children].first[:children].first[:name]).to eq('value')
      expect(hash[:children].first[:children].first[:type]).to eq('simple')
    end
  end

  describe '#==' do
    it 'considers elements with identical properties equal' do
      a = build_element(base_type: 'xsd:string')
      b = build_element(base_type: 'xsd:string')

      expect(a).to eq(b)
    end

    it 'considers elements with different names not equal' do
      a = build_element(name: 'first')
      b = build_element(name: 'second')

      expect(a).not_to eq(b)
    end

    it 'considers elements with different types not equal' do
      a = build_element(base_type: 'xsd:string')
      b = build_element(base_type: 'xsd:int')

      expect(a).not_to eq(b)
    end

    it 'considers elements with different children not equal' do
      child_a = build_element(name: 'a', base_type: 'xsd:string')
      child_b = build_element(name: 'b', base_type: 'xsd:string')

      a = build_element
      a.children = [child_a]
      b = build_element
      b.children = [child_b]

      expect(a).not_to eq(b)
    end

    it 'considers elements with identical children equal' do
      child_a = build_element(name: 'child', namespace: nil, form: 'unqualified', base_type: 'xsd:string')
      child_b = build_element(name: 'child', namespace: nil, form: 'unqualified', base_type: 'xsd:string')

      a = build_element
      a.children = [child_a]
      b = build_element
      b.children = [child_b]

      expect(a).to eq(b)
    end

    it 'considers elements with different attributes not equal' do
      a = build_element(attributes: [build_attribute(name: 'id')])
      b = build_element(attributes: [build_attribute(name: 'ref')])

      expect(a).not_to eq(b)
    end

    it 'ignores parent reference in comparison' do
      parent_a = build_element(name: 'root_a')
      parent_b = build_element(name: 'root_b')

      a = build_element(name: 'child')
      a.parent = parent_a
      b = build_element(name: 'child')
      b.parent = parent_b

      expect(a).to eq(b)
    end

    it 'returns false for non-Element objects' do
      expect(build_element).not_to eq('not an element')
    end
  end

  describe '#hash' do
    it 'returns the same hash for equal elements' do
      a = build_element(base_type: 'xsd:string')
      b = build_element(base_type: 'xsd:string')

      expect(a.hash).to eq(b.hash)
    end

    it 'can be used as a hash key' do
      a = build_element(base_type: 'xsd:string')
      b = build_element(base_type: 'xsd:string')

      map = { a => 'found' }
      expect(map[b]).to eq('found')
    end
  end
end
