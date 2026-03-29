# frozen_string_literal: true

RSpec.describe WSDL::Definition::Element do
  let(:simple_hash) do
    {
      'name' => 'age',
      'ns' => 'http://example.com',
      'type' => 'simple',
      'xsd_type' => 'xsd:int'
    }
  end

  let(:complex_hash) do
    {
      'name' => 'user',
      'ns' => 'http://example.com',
      'type' => 'complex',
      'complex_type_id' => 'http://example.com:UserType',
      'children' => [simple_hash],
      'attributes' => [{ 'name' => 'id', 'base_type' => 'xsd:string', 'use' => 'required', 'list' => false }]
    }
  end

  let(:recursive_hash) do
    {
      'name' => 'parent',
      'ns' => 'http://example.com',
      'type' => 'recursive',
      'min' => 0,
      'max' => 'unbounded',
      'nillable' => true,
      'recursive_type' => 'ParentType'
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

    it 'wraps children as Element instances' do
      expect(element.children).to all(be_a(described_class))
      expect(element.children.first.name).to eq('age')
    end

    it 'wraps attributes as Attribute instances' do
      expect(element.attributes).to all(be_a(WSDL::Definition::Attribute))
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

  describe '#singular? derivation from max_occurs' do
    it 'returns true when max_occurs is 1 and :singular key is absent' do
      hash = {
        'name' => 'item', 'ns' => 'http://example.com', 'form' => 'qualified',
        'type' => 'simple', 'xsd_type' => 'xsd:string',
        'min' => 1, 'max' => 1,
        'nillable' => false, 'list' => false, 'any_content' => false,
        'recursive_type' => nil, 'complex_type_id' => nil,
        'children' => [], 'attributes' => []
      }
      element = described_class.new(hash)
      expect(element).to be_singular
    end

    it 'returns false when max_occurs is unbounded and :singular key is absent' do
      hash = {
        'name' => 'items', 'ns' => 'http://example.com', 'form' => 'qualified',
        'type' => 'simple', 'xsd_type' => 'xsd:string',
        'min' => 0, 'max' => 'unbounded',
        'nillable' => false, 'list' => false, 'any_content' => false,
        'recursive_type' => nil, 'complex_type_id' => nil,
        'children' => [], 'attributes' => []
      }
      element = described_class.new(hash)
      expect(element).not_to be_singular
    end

    it 'derives from max_occurs, ignoring stored :singular field' do
      hash = {
        'name' => 'item', 'ns' => 'http://example.com', 'form' => 'qualified',
        'type' => 'simple', 'xsd_type' => 'xsd:string',
        'min' => 1, 'max' => 5,
        'nillable' => false, 'singular' => true, 'list' => false, 'any_content' => false,
        'recursive_type' => nil, 'complex_type_id' => nil,
        'children' => [], 'attributes' => []
      }
      element = described_class.new(hash)
      expect(element).not_to be_singular
    end
  end

  describe 'default fallbacks for absent fields' do
    subject(:element) do
      described_class.new({
        'name' => 'x',
        'type' => 'simple',
        'ns' => 'http://example.com',
        'xsd_type' => 'xs:string'
      })
    end

    it 'returns "qualified" for form' do
      expect(element.form).to eq('qualified')
    end

    it 'returns false for nillable?' do
      expect(element.nillable?).to be(false)
    end

    it 'returns false for list?' do
      expect(element.list?).to be(false)
    end

    it 'returns false for any_content?' do
      expect(element.any_content?).to be(false)
    end

    it 'returns nil for recursive_type' do
      expect(element.recursive_type).to be_nil
    end

    it 'returns base_type from xsd_type' do
      expect(element.base_type).to eq('xs:string')
    end

    it 'returns "1" for min_occurs' do
      expect(element.min_occurs).to eq('1')
    end

    it 'returns "1" for max_occurs' do
      expect(element.max_occurs).to eq('1')
    end

    it 'returns false for optional?' do
      expect(element.optional?).to be(false)
    end

    it 'returns true for required?' do
      expect(element.required?).to be(true)
    end

    it 'returns true for singular?' do
      expect(element.singular?).to be(true)
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
  end

  describe 'explicit values override defaults' do
    it 'uses explicit nillable over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'simple', 'ns' => 'http://example.com',
        'xsd_type' => 'xs:string', 'nillable' => true
      })
      expect(element.nillable?).to be(true)
    end

    it 'uses explicit form over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'simple', 'ns' => 'http://example.com',
        'xsd_type' => 'xs:string', 'form' => 'unqualified'
      })
      expect(element.form).to eq('unqualified')
    end

    it 'uses explicit list over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'simple', 'ns' => 'http://example.com',
        'xsd_type' => 'xs:string', 'list' => true
      })
      expect(element.list?).to be(true)
    end

    it 'uses explicit any_content over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'complex', 'ns' => 'http://example.com',
        'xsd_type' => nil, 'any_content' => true
      })
      expect(element.any_content?).to be(true)
    end

    it 'uses explicit min_occurs over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'simple', 'ns' => 'http://example.com',
        'xsd_type' => 'xs:string', 'min' => 0
      })
      expect(element.min_occurs).to eq('0')
      expect(element).to be_optional
    end

    it 'uses explicit max_occurs over default' do
      element = described_class.new({
        'name' => 'x', 'type' => 'simple', 'ns' => 'http://example.com',
        'xsd_type' => 'xs:string', 'max' => 'unbounded'
      })
      expect(element.max_occurs).to eq('unbounded')
      expect(element).not_to be_singular
    end

    it 'uses explicit children over default' do
      child = { 'name' => 'y', 'type' => 'simple', 'ns' => 'http://example.com', 'xsd_type' => 'xs:int' }
      element = described_class.new({
        'name' => 'x', 'type' => 'complex', 'ns' => 'http://example.com',
        'xsd_type' => nil, 'children' => [child]
      })
      expect(element.children.size).to eq(1)
      expect(element.children.first.name).to eq('y')
    end

    it 'uses explicit attributes over default' do
      attr = { 'name' => 'id', 'base_type' => 'xs:string', 'use' => 'required', 'list' => false }
      element = described_class.new({
        'name' => 'x', 'type' => 'complex', 'ns' => 'http://example.com',
        'xsd_type' => nil, 'attributes' => [attr]
      })
      expect(element.attributes.size).to eq(1)
      expect(element.attributes.first.name).to eq('id')
    end
  end

  describe 'duck-type compatibility with XML::Element' do
    it 'responds to all methods that Response::Parser calls' do
      element = described_class.new(simple_hash)

      %i[name namespace form singular? simple_type? complex_type? base_type list? children attributes].each do |method|
        expect(element).to respond_to(method), "Expected Element to respond to #{method}"
      end
    end

    it 'responds to all methods that Response::Builder calls' do
      element = described_class.new(simple_hash)

      methods = %i[
        name namespace form singular? simple_type? complex_type?
        base_type list? nillable? any_content? children attributes
      ]
      methods.each do |method|
        expect(element).to respond_to(method), "Expected Element to respond to #{method}"
      end
    end

    it 'responds to all methods that Request::Validator calls' do
      element = described_class.new(simple_hash)

      %i[name namespace form min_occurs max_occurs children attributes any_content?].each do |method|
        expect(element).to respond_to(method), "Expected Element to respond to #{method}"
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

  describe WSDL::Definition::Attribute do
    subject(:attribute) { described_class.new(attribute_hash) }

    let(:attribute_hash) do
      { 'name' => 'id', 'base_type' => 'xsd:string', 'use' => 'required', 'list' => false }
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
      optional = described_class.new(attribute_hash.merge('use' => 'optional'))
      expect(optional).to be_optional
    end

    it 'is frozen' do
      expect(attribute).to be_frozen
    end

    it 'returns the introspection-compatible hash via to_h' do
      expect(attribute.to_h).to eq({ name: 'id', type: 'xsd:string', required: true, list: false })
    end

    it 'returns the raw definition hash via to_definition_h' do
      expect(attribute.to_definition_h).to equal(attribute_hash)
    end

    it 'responds to all methods that Response::Parser calls on attributes' do
      %i[name base_type list?].each do |method|
        expect(attribute).to respond_to(method), "Expected Attribute to respond to #{method}"
      end
    end
  end
end
