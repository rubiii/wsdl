# frozen_string_literal: true

RSpec.describe WSDL::Definition::ElementHash do
  let(:simple_hash) do
    {
      name: 'age',
      namespace: 'http://example.com',
      form: 'qualified',
      type: :simple,
      xsd_type: 'xsd:int',
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
    }
  end

  let(:complex_hash) do
    {
      name: 'user',
      namespace: 'http://example.com',
      form: 'qualified',
      type: :complex,
      xsd_type: nil,
      min_occurs: 1,
      max_occurs: 1,
      nillable: false,
      singular: true,
      list: false,
      any_content: false,
      recursive_type: nil,
      complex_type_id: 'http://example.com:UserType',
      children: [simple_hash],
      attributes: [{ name: 'id', base_type: 'xsd:string', use: 'required', list: false }]
    }
  end

  let(:recursive_hash) do
    {
      name: 'parent',
      namespace: 'http://example.com',
      form: 'qualified',
      type: :recursive,
      xsd_type: nil,
      min_occurs: 0,
      max_occurs: Float::INFINITY,
      nillable: true,
      singular: false,
      list: false,
      any_content: false,
      recursive_type: 'ParentType',
      complex_type_id: nil,
      children: [],
      attributes: []
    }
  end

  describe 'simple element' do
    subject(:element) { described_class.new(simple_hash) }

    it 'returns name' do
      expect(element.name).to eq('age')
    end

    it 'returns namespace' do
      expect(element.namespace).to eq('http://example.com')
    end

    it 'returns form' do
      expect(element.form).to eq('qualified')
    end

    it 'returns kind' do
      expect(element.kind).to eq(:simple)
    end

    it 'returns base_type' do
      expect(element.base_type).to eq('xsd:int')
    end

    it 'reports simple_type?' do
      expect(element).to be_simple_type
    end

    it 'does not report complex_type?' do
      expect(element).not_to be_complex_type
    end

    it 'reports singular?' do
      expect(element).to be_singular
    end

    it 'does not report list?' do
      expect(element).not_to be_list
    end

    it 'does not report nillable?' do
      expect(element).not_to be_nillable
    end

    it 'does not report any_content?' do
      expect(element).not_to be_any_content
    end

    it 'does not report recursive?' do
      expect(element).not_to be_recursive
    end

    it 'returns nil recursive_type' do
      expect(element.recursive_type).to be_nil
    end

    it 'returns min_occurs as string' do
      expect(element.min_occurs).to eq('1')
    end

    it 'returns max_occurs as string' do
      expect(element.max_occurs).to eq('1')
    end

    it 'reports required?' do
      expect(element).to be_required
    end

    it 'does not report optional?' do
      expect(element).not_to be_optional
    end

    it 'returns empty children' do
      expect(element.children).to eq([])
    end

    it 'returns empty attributes' do
      expect(element.attributes).to eq([])
    end

    it 'is frozen' do
      expect(element).to be_frozen
    end

    it 'returns the underlying hash via to_h' do
      expect(element.to_h).to equal(simple_hash)
    end
  end

  describe 'complex element with children and attributes' do
    subject(:element) { described_class.new(complex_hash) }

    it 'reports complex_type?' do
      expect(element).to be_complex_type
    end

    it 'does not report simple_type?' do
      expect(element).not_to be_simple_type
    end

    it 'wraps children as ElementHash instances' do
      expect(element.children).to all(be_a(described_class))
      expect(element.children.first.name).to eq('age')
    end

    it 'wraps attributes as AttributeHash instances' do
      expect(element.attributes).to all(be_a(WSDL::Definition::AttributeHash))
      expect(element.attributes.first.name).to eq('id')
    end

    it 'caches children across calls' do
      expect(element.children).to equal(element.children)
    end

    it 'caches attributes across calls' do
      expect(element.attributes).to equal(element.attributes)
    end
  end

  describe 'recursive element' do
    subject(:element) { described_class.new(recursive_hash) }

    it 'reports recursive?' do
      expect(element).to be_recursive
    end

    it 'reports complex_type? (recursive is a subset of complex)' do
      expect(element).to be_complex_type
    end

    it 'returns recursive_type' do
      expect(element.recursive_type).to eq('ParentType')
    end

    it 'returns max_occurs as unbounded' do
      expect(element.max_occurs).to eq('unbounded')
    end

    it 'reports optional?' do
      expect(element).to be_optional
    end

    it 'does not report singular?' do
      expect(element).not_to be_singular
    end

    it 'reports nillable?' do
      expect(element).to be_nillable
    end
  end

  describe 'duck-type compatibility with XML::Element' do
    it 'responds to all methods that Response::Parser calls' do
      element = described_class.new(simple_hash)

      %i[name namespace form singular? simple_type? complex_type? base_type list? children attributes].each do |method|
        expect(element).to respond_to(method), "Expected ElementHash to respond to #{method}"
      end
    end

    it 'responds to all methods that Response::Builder calls' do
      element = described_class.new(simple_hash)

      methods = %i[
        name namespace form singular? simple_type? complex_type?
        base_type list? nillable? any_content? children attributes
      ]
      methods.each do |method|
        expect(element).to respond_to(method), "Expected ElementHash to respond to #{method}"
      end
    end

    it 'responds to all methods that Request::Validator calls' do
      element = described_class.new(simple_hash)

      %i[name namespace form min_occurs max_occurs children attributes any_content?].each do |method|
        expect(element).to respond_to(method), "Expected ElementHash to respond to #{method}"
      end
    end

    it 'round-trips through XML::Element#to_definition_h' do
      xml_element = WSDL::XML::Element.new
      xml_element.name = 'test'
      xml_element.namespace = 'http://example.com'
      xml_element.form = 'qualified'
      xml_element.base_type = 'xsd:string'

      hash = xml_element.to_definition_h
      wrapped = described_class.new(hash)

      expect(wrapped.name).to eq(xml_element.name)
      expect(wrapped.namespace).to eq(xml_element.namespace)
      expect(wrapped.form).to eq(xml_element.form)
      expect(wrapped.base_type).to eq(xml_element.base_type)
      expect(wrapped.simple_type?).to eq(xml_element.simple_type?)
      expect(wrapped.singular?).to eq(xml_element.singular?)
      expect(wrapped.min_occurs).to eq(xml_element.min_occurs)
      expect(wrapped.max_occurs).to eq(xml_element.max_occurs)
    end
  end

  describe WSDL::Definition::AttributeHash do
    subject(:attribute) { described_class.new(attribute_hash) }

    let(:attribute_hash) do
      { name: 'id', base_type: 'xsd:string', use: 'required', list: false }
    end

    it 'returns name' do
      expect(attribute.name).to eq('id')
    end

    it 'returns base_type' do
      expect(attribute.base_type).to eq('xsd:string')
    end

    it 'returns use' do
      expect(attribute.use).to eq('required')
    end

    it 'does not report list?' do
      expect(attribute).not_to be_list
    end

    it 'does not report optional? for required attributes' do
      expect(attribute).not_to be_optional
    end

    it 'reports optional? for optional attributes' do
      optional = described_class.new(attribute_hash.merge(use: 'optional'))
      expect(optional).to be_optional
    end

    it 'is frozen' do
      expect(attribute).to be_frozen
    end

    it 'returns the underlying hash via to_h' do
      expect(attribute.to_h).to equal(attribute_hash)
    end

    it 'responds to all methods that Response::Parser calls on attributes' do
      %i[name base_type list?].each do |method|
        expect(attribute).to respond_to(method), "Expected AttributeHash to respond to #{method}"
      end
    end
  end
end
