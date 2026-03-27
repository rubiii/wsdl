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

  describe '#children' do
    subject(:element) { described_class.new }

    it 'defaults to a shared empty frozen array' do
      expect(element.children).to eq([])
      expect(element.children).to be_frozen
      expect(element.children).to be(described_class::EMPTY_CHILDREN)
    end

    it 'shares the same empty array instance across elements' do
      other = described_class.new
      expect(element.children).to be(other.children)
    end

    it 'can be replaced with a populated array' do
      child = build_element(name: 'child', base_type: 'xsd:string')
      element.children = [child]

      expect(element.children).to eq([child])
      expect(element.children).not_to be(described_class::EMPTY_CHILDREN)
    end
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

  describe '#freeze' do
    it 'freezes the children array' do
      child = build_element(name: 'child', base_type: 'xsd:string')
      element = build_element
      element.children = [child]

      expect(element.children).not_to be_frozen
      element.freeze
      expect(element.children).to be_frozen
    end

    it 'eagerly computes the definition hash' do
      element = build_element(base_type: 'xsd:string')
      element.freeze

      hash = element.to_definition_h
      expect(hash).to be_frozen
      expect(hash[:name]).to eq('user')
      expect(hash[:type]).to eq('simple')
    end

    it 'caches the definition hash so repeated calls return the same object' do
      element = build_element(base_type: 'xsd:string')
      element.freeze

      first_result = element.to_definition_h
      expect(first_result).to be(element.to_definition_h)
    end

    it 'is idempotent' do
      element = build_element(base_type: 'xsd:string')
      element.freeze
      hash_before = element.to_definition_h

      expect { element.freeze }.not_to raise_error
      expect(element.to_definition_h).to be(hash_before)
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

    context 'when the element is frozen' do
      it 'returns the same object on repeated calls' do
        element = build_element(base_type: 'xsd:string')
        element.freeze

        first_call = element.to_definition_h
        second_call = element.to_definition_h

        expect(first_call).to be(second_call)
      end

      it 'returns the same child hash objects for shared children' do
        child = build_element(name: 'shared', namespace: nil, form: 'unqualified', base_type: 'xsd:string')
        child.freeze

        parent_a = build_element(name: 'a')
        parent_a.children = [child]
        parent_a.freeze

        parent_b = build_element(name: 'b')
        parent_b.children = [child]
        parent_b.freeze

        child_hash_a = parent_a.to_definition_h[:children].first
        child_hash_b = parent_b.to_definition_h[:children].first

        expect(child_hash_a).to be(child_hash_b)
      end

      it 'produces correct results for a deep frozen tree' do
        leaf = build_element(name: 'value', namespace: nil, form: 'unqualified', base_type: 'xsd:string')
        leaf.freeze
        mid = build_element(name: 'item', namespace: nil, form: 'unqualified')
        mid.children = [leaf]
        mid.freeze
        root = build_element(name: 'items')
        root.children = [mid]
        root.freeze

        hash = root.to_definition_h
        expect(hash[:name]).to eq('items')
        expect(hash[:children].first[:name]).to eq('item')
        expect(hash[:children].first[:children].first[:name]).to eq('value')
        expect(hash[:children].first[:children].first[:type]).to eq('simple')
      end
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
