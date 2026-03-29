# frozen_string_literal: true

RSpec.describe WSDL::XML::Attribute do
  def build_attribute(name: 'id', base_type: 'xsd:string', use: 'optional', list: false)
    attr = described_class.new
    attr.name = name
    attr.base_type = base_type
    attr.use = use
    attr.list = list
    attr
  end

  describe '#to_definition_h' do
    it 'returns a hash with raw schema properties' do
      attr = build_attribute(name: 'code', base_type: 'xsd:int', use: 'required', list: false)

      expect(attr.to_definition_h).to eq({
        'name' => 'code',
        'base_type' => 'xsd:int',
        'use' => 'required',
        'list' => false
      })
    end

    it 'preserves list flag' do
      attr = build_attribute(list: true)

      expect(attr.to_definition_h['list']).to be true
    end

    it 'differs from to_h in field names' do
      attr = build_attribute(name: 'id', base_type: 'xsd:string', use: 'optional')

      definition_h = attr.to_definition_h
      introspection_h = attr.to_h

      expect(definition_h).to have_key('base_type')
      expect(definition_h).to have_key('use')
      expect(introspection_h).to have_key(:type)
      expect(introspection_h).to have_key(:required)
    end
  end

  describe '#==' do
    it 'considers attributes with identical properties equal' do
      a = build_attribute
      b = build_attribute

      expect(a).to eq(b)
    end

    it 'considers attributes with different names not equal' do
      a = build_attribute(name: 'id')
      b = build_attribute(name: 'ref')

      expect(a).not_to eq(b)
    end

    it 'considers attributes with different types not equal' do
      a = build_attribute(base_type: 'xsd:string')
      b = build_attribute(base_type: 'xsd:int')

      expect(a).not_to eq(b)
    end

    it 'considers attributes with different use not equal' do
      a = build_attribute(use: 'optional')
      b = build_attribute(use: 'required')

      expect(a).not_to eq(b)
    end

    it 'considers attributes with different list flags not equal' do
      a = build_attribute(list: false)
      b = build_attribute(list: true)

      expect(a).not_to eq(b)
    end

    it 'returns false for non-Attribute objects' do
      expect(build_attribute).not_to eq('not an attribute')
    end
  end

  describe '#hash' do
    it 'returns the same hash for equal attributes' do
      a = build_attribute
      b = build_attribute

      expect(a.hash).to eq(b.hash)
    end

    it 'can be used as a hash key' do
      a = build_attribute
      b = build_attribute

      map = { a => 'found' }
      expect(map[b]).to eq('found')
    end
  end
end
