# frozen_string_literal: true

require 'logger'

RSpec.describe WSDL::Schema::Collection do
  subject(:collection) { described_class.new }

  describe '#initialize' do
    it 'creates an empty collection' do
      expect(collection.count).to eq(0)
    end
  end

  describe '#<<' do
    let(:definition) do
      instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://example.com'
      )
    end

    it 'adds a definition to the collection' do
      collection << definition
      expect(collection.count).to eq(1)
    end

    it 'returns self for chaining' do
      result = collection << definition
      expect(result).to be(collection)
    end
  end

  describe '#push' do
    let(:definitions) do
      [
        instance_double(WSDL::Schema::Definition, target_namespace: 'http://example.com/one'),
        instance_double(WSDL::Schema::Definition, target_namespace: 'http://example.com/two')
      ]
    end

    it 'adds multiple definitions to the collection' do
      collection.push(definitions)
      expect(collection.count).to eq(2)
    end

    it 'returns self for chaining' do
      result = collection.push(definitions)
      expect(result).to be(collection)
    end
  end

  describe '#each' do
    let(:definitions) do
      [
        instance_double(WSDL::Schema::Definition, target_namespace: 'http://example.com/one'),
        instance_double(WSDL::Schema::Definition, target_namespace: 'http://example.com/two')
      ]
    end

    before do
      collection.push(definitions)
    end

    it 'yields each definition' do
      yielded = collection.map { |d|
        d
      }
      expect(yielded).to eq(definitions)
    end

    it 'returns an Enumerator when no block given' do
      expect(collection.each).to be_a(Enumerator)
    end

    it 'supports Enumerable methods' do
      expect(collection).to respond_to(:map)
      expect(collection).to respond_to(:select)
      expect(collection).to respond_to(:find)
    end
  end

  describe '#find_by_namespace' do
    let(:definition) do
      instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://example.com/test'
      )
    end

    before do
      collection << definition
    end

    it 'returns definition matching the namespace' do
      result = collection.find_by_namespace('http://example.com/test')
      expect(result).to eq(definition)
    end

    it 'returns nil when namespace not found' do
      result = collection.find_by_namespace('http://example.com/other')
      expect(result).to be_nil
    end
  end

  context 'with a populated collection' do
    let(:element_node) { instance_double(WSDL::Schema::Node, kind: :element, name: 'User') }
    let(:complex_type_node) { instance_double(WSDL::Schema::Node, kind: :complexType, name: 'UserType') }
    let(:simple_type_node) { instance_double(WSDL::Schema::Node, kind: :simpleType, name: 'StatusType') }
    let(:attribute_node) { instance_double(WSDL::Schema::Node, kind: :attribute, name: 'id') }
    let(:attribute_group_node) { instance_double(WSDL::Schema::Node, kind: :attributeGroup, name: 'CommonAttrs') }
    let(:group_node) { instance_double(WSDL::Schema::Node, kind: :group, name: 'AddressGroup') }

    let(:definition) do
      instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://example.com/test',
        elements: { 'User' => element_node },
        complex_types: { 'UserType' => complex_type_node },
        simple_types: { 'StatusType' => simple_type_node },
        attributes: { 'id' => attribute_node },
        attribute_groups: { 'CommonAttrs' => attribute_group_node },
        groups: { 'AddressGroup' => group_node }
      )
    end

    before do
      collection << definition
    end

    describe '#find_element' do
      it 'returns the element when found' do
        result = collection.find_element('http://example.com/test', 'User')
        expect(result).to eq(element_node)
      end

      it 'returns nil when element not found in schema' do
        result = collection.find_element('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_element('http://unknown.com', 'User')).to be_nil
      end

      it 'returns nil for nil namespace' do
        expect(collection.find_element(nil, 'User')).to be_nil
      end
    end

    describe '#find_complex_type' do
      it 'returns the complex type when found' do
        result = collection.find_complex_type('http://example.com/test', 'UserType')
        expect(result).to eq(complex_type_node)
      end

      it 'returns nil when type not found in schema' do
        result = collection.find_complex_type('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_complex_type('http://unknown.com', 'UserType')).to be_nil
      end
    end

    describe '#find_simple_type' do
      it 'returns the simple type when found' do
        result = collection.find_simple_type('http://example.com/test', 'StatusType')
        expect(result).to eq(simple_type_node)
      end

      it 'returns nil when type not found in schema' do
        result = collection.find_simple_type('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_simple_type('http://unknown.com', 'StatusType')).to be_nil
      end
    end

    describe '#find_type' do
      it 'returns complex type when found' do
        result = collection.find_type('http://example.com/test', 'UserType')
        expect(result).to eq(complex_type_node)
      end

      it 'returns simple type when complex type not found' do
        result = collection.find_type('http://example.com/test', 'StatusType')
        expect(result).to eq(simple_type_node)
      end

      it 'returns nil when neither type found' do
        result = collection.find_type('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_type('http://unknown.com', 'UserType')).to be_nil
      end
    end

    describe '#find_attribute' do
      it 'returns the attribute when found' do
        result = collection.find_attribute('http://example.com/test', 'id')
        expect(result).to eq(attribute_node)
      end

      it 'returns nil when attribute not found in schema' do
        result = collection.find_attribute('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_attribute('http://unknown.com', 'id')).to be_nil
      end
    end

    describe '#find_attribute_group' do
      it 'returns the attribute group when found' do
        result = collection.find_attribute_group('http://example.com/test', 'CommonAttrs')
        expect(result).to eq(attribute_group_node)
      end

      it 'returns nil when group not found in schema' do
        result = collection.find_attribute_group('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_attribute_group('http://unknown.com', 'CommonAttrs')).to be_nil
      end
    end

    describe '#find_group' do
      it 'returns the group when found' do
        result = collection.find_group('http://example.com/test', 'AddressGroup')
        expect(result).to eq(group_node)
      end

      it 'returns nil when group not found in schema' do
        result = collection.find_group('http://example.com/test', 'NonExistent')
        expect(result).to be_nil
      end

      it 'returns nil when namespace not found' do
        expect(collection.find_group('http://unknown.com', 'AddressGroup')).to be_nil
      end
    end
  end

  context 'with multiple definitions sharing a namespace' do
    let(:element_a) { instance_double(WSDL::Schema::Node, kind: :element, name: 'Alpha') }
    let(:element_b) { instance_double(WSDL::Schema::Node, kind: :element, name: 'Beta') }
    let(:complex_type_a) { instance_double(WSDL::Schema::Node, kind: :complexType, name: 'TypeA') }
    let(:simple_type_b) { instance_double(WSDL::Schema::Node, kind: :simpleType, name: 'TypeB') }
    let(:attribute_b) { instance_double(WSDL::Schema::Node, kind: :attribute, name: 'attrB') }
    let(:group_b) { instance_double(WSDL::Schema::Node, kind: :group, name: 'GroupB') }
    let(:attr_group_b) { instance_double(WSDL::Schema::Node, kind: :attributeGroup, name: 'AttrGroupB') }

    let(:definition_a) do
      instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://shared.com',
        elements: { 'Alpha' => element_a },
        complex_types: { 'TypeA' => complex_type_a },
        simple_types: {},
        attributes: {},
        groups: {},
        attribute_groups: {}
      )
    end

    let(:definition_b) do
      instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://shared.com',
        elements: { 'Beta' => element_b },
        complex_types: {},
        simple_types: { 'TypeB' => simple_type_b },
        attributes: { 'attrB' => attribute_b },
        groups: { 'GroupB' => group_b },
        attribute_groups: { 'AttrGroupB' => attr_group_b }
      )
    end

    before do
      collection << definition_a
      collection << definition_b
    end

    it 'finds element in first definition' do
      expect(collection.find_element('http://shared.com', 'Alpha')).to eq(element_a)
    end

    it 'finds element in second definition' do
      expect(collection.find_element('http://shared.com', 'Beta')).to eq(element_b)
    end

    it 'returns nil when element is in neither definition' do
      expect(collection.find_element('http://shared.com', 'Missing')).to be_nil
    end

    it 'finds complex type across definitions' do
      expect(collection.find_complex_type('http://shared.com', 'TypeA')).to eq(complex_type_a)
    end

    it 'finds simple type across definitions' do
      expect(collection.find_simple_type('http://shared.com', 'TypeB')).to eq(simple_type_b)
    end

    it 'finds complex type in one definition and simple type in another via find_type' do
      expect(collection.find_type('http://shared.com', 'TypeA')).to eq(complex_type_a)
      expect(collection.find_type('http://shared.com', 'TypeB')).to eq(simple_type_b)
    end

    it 'finds attribute across definitions' do
      expect(collection.find_attribute('http://shared.com', 'attrB')).to eq(attribute_b)
    end

    it 'finds group across definitions' do
      expect(collection.find_group('http://shared.com', 'GroupB')).to eq(group_b)
    end

    it 'finds attribute group across definitions' do
      expect(collection.find_attribute_group('http://shared.com', 'AttrGroupB')).to eq(attr_group_b)
    end

    it 'find_by_namespace returns the first definition' do
      expect(collection.find_by_namespace('http://shared.com')).to eq(definition_a)
    end

    it 'maintains index when mixing << and push' do
      fresh = described_class.new
      fresh << definition_a
      fresh.push([definition_b])

      expect(fresh.find_element('http://shared.com', 'Alpha')).to eq(element_a)
      expect(fresh.find_element('http://shared.com', 'Beta')).to eq(element_b)
    end

    it 'handles nil namespace with multiple definitions' do
      nil_def_a = instance_double(
        WSDL::Schema::Definition,
        target_namespace: nil,
        elements: { 'X' => element_a }
      )
      nil_def_b = instance_double(
        WSDL::Schema::Definition,
        target_namespace: nil,
        elements: { 'Y' => element_b }
      )

      fresh = described_class.new
      fresh << nil_def_a
      fresh << nil_def_b

      expect(fresh.find_element(nil, 'X')).to eq(element_a)
      expect(fresh.find_element(nil, 'Y')).to eq(element_b)
    end
  end

  describe '#release_dom_references!' do
    def new_definition(xml, collection = nil)
      node = Nokogiri.XML(xml).root
      WSDL::Schema::Definition.new(node, collection)
    end

    it 'releases DOM references from all definitions' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
        </xs:schema>
      ')
      collection << definition

      collection.release_dom_references!

      definition.elements.each_value do |node|
        expect(node.xml_node).to be_nil
      end
    end

    it 'handles an empty collection' do
      expect { collection.release_dom_references! }.not_to raise_error
    end
  end

  describe 'missing namespace behavior' do
    it 'returns nil for unknown namespace even when other schemas exist' do
      definition = instance_double(
        WSDL::Schema::Definition,
        target_namespace: 'http://example.com/known'
      )
      collection << definition

      expect(collection.find_element('http://example.com/unknown', 'Test')).to be_nil
    end

    it 'returns nil when no schemas available' do
      expect(collection.find_element('http://example.com/test', 'Test')).to be_nil
    end
  end
end

RSpec.describe WSDL::Schema::Definition do
  def new_definition(xml, collection = nil, source_location = nil)
    node = Nokogiri.XML(xml).root
    described_class.new(node, collection, source_location)
  end

  describe '#initialize' do
    it 'parses target namespace' do
      definition = new_definition('
        <xs:schema targetNamespace="http://example.com"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      ')
      expect(definition.target_namespace).to eq('http://example.com')
    end

    it 'parses element form default' do
      definition = new_definition('
        <xs:schema elementFormDefault="qualified"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      ')
      expect(definition.element_form_default).to eq('qualified')
    end

    it 'defaults element form to unqualified' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>
      ')
      expect(definition.element_form_default).to eq('unqualified')
    end

    it 'stores source location' do
      definition = new_definition(
        '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>',
        nil,
        'http://example.com/schema.xsd'
      )
      expect(definition.source_location).to eq('http://example.com/schema.xsd')
    end
  end

  describe '#elements' do
    it 'parses global element declarations' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
          <xs:element name="Order" type="xs:string"/>
        </xs:schema>
      ')

      expect(definition.elements.keys).to contain_exactly('User', 'Order')
      expect(definition.elements['User']).to be_a(WSDL::Schema::Node)
      expect(definition.elements['User'].kind).to eq(:element)
    end
  end

  describe '#complex_types' do
    it 'parses complex type definitions' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="UserType">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:schema>
      ')

      expect(definition.complex_types.keys).to contain_exactly('UserType')
      expect(definition.complex_types['UserType']).to be_a(WSDL::Schema::Node)
      expect(definition.complex_types['UserType'].kind).to eq(:complexType)
    end
  end

  describe '#simple_types' do
    it 'parses simple type definitions' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType name="StatusType">
            <xs:restriction base="xs:string">
              <xs:enumeration value="active"/>
              <xs:enumeration value="inactive"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:schema>
      ')

      expect(definition.simple_types.keys).to contain_exactly('StatusType')
      expect(definition.simple_types['StatusType']).to be_a(WSDL::Schema::Node)
      expect(definition.simple_types['StatusType'].kind).to eq(:simpleType)
    end
  end

  describe '#attributes' do
    it 'parses global attribute declarations' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:attribute name="id" type="xs:int"/>
          <xs:attribute name="lang" type="xs:string"/>
        </xs:schema>
      ')

      expect(definition.attributes.keys).to contain_exactly('id', 'lang')
      expect(definition.attributes['id']).to be_a(WSDL::Schema::Node)
      expect(definition.attributes['id'].kind).to eq(:attribute)
    end
  end

  describe '#attribute_groups' do
    it 'parses attribute group definitions' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:attributeGroup name="CommonAttrs">
            <xs:attribute name="id" type="xs:int"/>
            <xs:attribute name="class" type="xs:string"/>
          </xs:attributeGroup>
        </xs:schema>
      ')

      expect(definition.attribute_groups.keys).to contain_exactly('CommonAttrs')
      expect(definition.attribute_groups['CommonAttrs']).to be_a(WSDL::Schema::Node)
      expect(definition.attribute_groups['CommonAttrs'].kind).to eq(:attributeGroup)
    end
  end

  describe '#groups' do
    it 'parses model group definitions' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:group name="AddressGroup">
            <xs:sequence>
              <xs:element name="street" type="xs:string"/>
              <xs:element name="city" type="xs:string"/>
            </xs:sequence>
          </xs:group>
        </xs:schema>
      ')

      expect(definition.groups.keys).to contain_exactly('AddressGroup')
      expect(definition.groups['AddressGroup']).to be_a(WSDL::Schema::Node)
      expect(definition.groups['AddressGroup'].kind).to eq(:group)
    end
  end

  describe '#imports' do
    it 'parses import declarations' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:import namespace="http://other.com" schemaLocation="other.xsd"/>
          <xs:import namespace="http://another.com" schemaLocation="another.xsd"/>
        </xs:schema>
      ')

      expect(definition.imports).to eq({
        'http://other.com' => 'other.xsd',
        'http://another.com' => 'another.xsd'
      })
    end

    it 'handles imports without schema location' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:import namespace="http://other.com"/>
        </xs:schema>
      ')

      expect(definition.imports).to eq({ 'http://other.com' => nil })
    end
  end

  describe '#import_locations' do
    it 'collects all schema locations' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:import namespace="http://other.com" schemaLocation="other.xsd"/>
          <xs:import namespace="http://another.com" schemaLocation="another.xsd"/>
        </xs:schema>
      ')

      expect(definition.import_locations).to eq(%w[other.xsd another.xsd])
    end

    it 'collects multiple locations for the same namespace' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:import namespace="http://shared.com" schemaLocation="a.xsd"/>
          <xs:import namespace="http://shared.com" schemaLocation="b.xsd"/>
        </xs:schema>
      ')

      expect(definition.import_locations).to eq(%w[a.xsd b.xsd])
    end

    it 'excludes imports without schema location' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:import namespace="http://other.com"/>
          <xs:import namespace="http://another.com" schemaLocation="another.xsd"/>
        </xs:schema>
      ')

      expect(definition.import_locations).to eq(['another.xsd'])
    end
  end

  describe '#includes' do
    it 'parses include declarations' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:include schemaLocation="common.xsd"/>
          <xs:include schemaLocation="types.xsd"/>
        </xs:schema>
      ')

      expect(definition.includes).to eq(%w[common.xsd types.xsd])
    end

    it 'ignores includes without schema location' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:include/>
          <xs:include schemaLocation="types.xsd"/>
        </xs:schema>
      ')

      expect(definition.includes).to eq(['types.xsd'])
    end
  end

  describe '#merge' do
    let(:base_definition) do
      new_definition('
        <xs:schema targetNamespace="http://example.com"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="BaseElement" type="xs:string"/>
          <xs:complexType name="BaseType">
            <xs:sequence/>
          </xs:complexType>
          <xs:simpleType name="BaseSimple">
            <xs:restriction base="xs:string"/>
          </xs:simpleType>
          <xs:attribute name="baseAttr" type="xs:string"/>
          <xs:attributeGroup name="BaseGroup">
            <xs:attribute name="a" type="xs:string"/>
          </xs:attributeGroup>
          <xs:import namespace="http://other.com" schemaLocation="other.xsd"/>
          <xs:include schemaLocation="base-include.xsd"/>
        </xs:schema>
      ')
    end

    let(:other_definition) do
      new_definition('
        <xs:schema targetNamespace="http://example.com"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="OtherElement" type="xs:string"/>
          <xs:complexType name="OtherType">
            <xs:sequence/>
          </xs:complexType>
          <xs:simpleType name="OtherSimple">
            <xs:restriction base="xs:int"/>
          </xs:simpleType>
          <xs:attribute name="otherAttr" type="xs:int"/>
          <xs:attributeGroup name="OtherGroup">
            <xs:attribute name="b" type="xs:int"/>
          </xs:attributeGroup>
          <xs:import namespace="http://another.com" schemaLocation="another.xsd"/>
          <xs:include schemaLocation="other-include.xsd"/>
        </xs:schema>
      ')
    end

    before do
      base_definition.merge(other_definition)
    end

    it 'merges elements' do
      expect(base_definition.elements.keys).to contain_exactly('BaseElement', 'OtherElement')
    end

    it 'merges complex types' do
      expect(base_definition.complex_types.keys).to contain_exactly('BaseType', 'OtherType')
    end

    it 'merges simple types' do
      expect(base_definition.simple_types.keys).to contain_exactly('BaseSimple', 'OtherSimple')
    end

    it 'merges attributes' do
      expect(base_definition.attributes.keys).to contain_exactly('baseAttr', 'otherAttr')
    end

    it 'merges attribute groups' do
      expect(base_definition.attribute_groups.keys).to contain_exactly('BaseGroup', 'OtherGroup')
    end

    it 'merges imports' do
      expect(base_definition.imports).to eq({
        'http://other.com' => 'other.xsd',
        'http://another.com' => 'another.xsd'
      })
    end

    it 'merges import locations' do
      expect(base_definition.import_locations).to eq(%w[other.xsd another.xsd])
    end

    it 'merges includes' do
      expect(base_definition.includes).to eq(%w[base-include.xsd other-include.xsd])
    end

    context 'with conflicting definitions' do
      let(:conflict_base) do
        new_definition('
          <xs:schema targetNamespace="http://example.com"
                     xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="SharedElement" type="xs:string"/>
            <xs:complexType name="SharedType">
              <xs:sequence/>
            </xs:complexType>
          </xs:schema>
        ')
      end

      let(:conflicting_definition) do
        new_definition('
          <xs:schema targetNamespace="http://example.com"
                     xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="SharedElement" type="xs:int"/>
            <xs:complexType name="SharedType">
              <xs:sequence>
                <xs:element name="inner" type="xs:string"/>
              </xs:sequence>
            </xs:complexType>
          </xs:schema>
        ')
      end

      it 'logs warnings for conflicting components' do
        log_output = StringIO.new
        WSDL.logger = Logger.new(log_output)

        conflict_base.merge(conflicting_definition)

        expect(log_output.string).to match(
          %r{element 'SharedElement'.*namespace 'http://example\.com'.*multiple xs:include}
        )
        expect(log_output.string).to match(
          %r{complex_type 'SharedType'.*namespace 'http://example\.com'.*multiple xs:include}
        )
      end

      it 'uses the duplicate definition (last write wins)' do
        WSDL.logger = Logger.new(StringIO.new)

        conflict_base.merge(conflicting_definition)

        expect(conflict_base.elements['SharedElement'].type).to eq('xs:int')
      end
    end

    context 'without conflicts' do
      it 'does not log any warnings' do
        log_output = StringIO.new

        no_conflict_base = new_definition('
          <xs:schema targetNamespace="http://example.com"
                     xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="Alpha" type="xs:string"/>
          </xs:schema>
        ')
        no_conflict_other = new_definition('
          <xs:schema targetNamespace="http://example.com"
                     xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:element name="Beta" type="xs:int"/>
          </xs:schema>
        ')

        WSDL.logger = Logger.new(log_output)

        no_conflict_base.merge(no_conflict_other)

        expect(log_output.string).not_to match(/WARN/)
      end
    end
  end

  describe 'context propagation' do
    it 'passes target namespace to parsed nodes' do
      definition = new_definition('
        <xs:schema targetNamespace="http://example.com"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
        </xs:schema>
      ')

      element = definition.elements['User']
      expect(element.namespace).to eq('http://example.com')
    end

    it 'passes element form default to parsed nodes' do
      definition = new_definition('
        <xs:schema targetNamespace="http://example.com"
                   elementFormDefault="qualified"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType name="UserType">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:schema>
      ')

      user_type = definition.complex_types['UserType']
      name_element = user_type.elements.first
      expect(name_element.form).to eq('qualified')
    end
  end

  describe 'with full schema' do
    it 'parses a complete schema with all components' do
      definition = new_definition('
        <xs:schema targetNamespace="http://example.com/api"
                   elementFormDefault="qualified"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/api">

          <xs:import namespace="http://common.com" schemaLocation="common.xsd"/>
          <xs:include schemaLocation="types.xsd"/>

          <xs:element name="GetUserRequest">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="userId" type="xs:int"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>

          <xs:element name="GetUserResponse" type="tns:UserType"/>

          <xs:complexType name="UserType">
            <xs:sequence>
              <xs:element name="id" type="xs:int"/>
              <xs:element name="name" type="xs:string"/>
              <xs:element name="status" type="tns:StatusType"/>
            </xs:sequence>
            <xs:attribute name="version" type="xs:int"/>
          </xs:complexType>

          <xs:simpleType name="StatusType">
            <xs:restriction base="xs:string">
              <xs:enumeration value="active"/>
              <xs:enumeration value="inactive"/>
            </xs:restriction>
          </xs:simpleType>

          <xs:attribute name="globalId" type="xs:string"/>

          <xs:attributeGroup name="CommonAttrs">
            <xs:attribute name="lang" type="xs:string"/>
          </xs:attributeGroup>

        </xs:schema>
      ')

      expect(definition.target_namespace).to eq('http://example.com/api')
      expect(definition.element_form_default).to eq('qualified')

      expect(definition.elements.keys).to contain_exactly('GetUserRequest', 'GetUserResponse')
      expect(definition.complex_types.keys).to contain_exactly('UserType')
      expect(definition.simple_types.keys).to contain_exactly('StatusType')
      expect(definition.attributes.keys).to contain_exactly('globalId')
      expect(definition.attribute_groups.keys).to contain_exactly('CommonAttrs')

      expect(definition.imports).to eq({ 'http://common.com' => 'common.xsd' })
      expect(definition.includes).to eq(['types.xsd'])

      # Verify nested structure is parsed correctly
      user_type = definition.complex_types['UserType']
      elements = user_type.elements
      expect(elements.map(&:name)).to eq(%w[id name status])

      attributes = user_type.attributes
      expect(attributes.map(&:name)).to eq(['version'])
    end
  end

  describe '#release_dom_references!' do
    it 'clears the underlying schema node' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
        </xs:schema>
      ')

      definition.release_dom_references!

      expect(definition.instance_variable_get(:@schema_node)).to be_nil
    end

    it 'releases DOM references from all component nodes' do
      definition = new_definition('
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
          <xs:complexType name="UserType">
            <xs:sequence/>
          </xs:complexType>
          <xs:simpleType name="StatusType">
            <xs:restriction base="xs:string"/>
          </xs:simpleType>
          <xs:attribute name="id" type="xs:int"/>
          <xs:attributeGroup name="CommonAttrs">
            <xs:attribute name="lang" type="xs:string"/>
          </xs:attributeGroup>
          <xs:group name="AddressGroup">
            <xs:sequence>
              <xs:element name="street" type="xs:string"/>
            </xs:sequence>
          </xs:group>
        </xs:schema>
      ')

      definition.release_dom_references!

      all_nodes = definition.elements.values +
                  definition.complex_types.values +
                  definition.simple_types.values +
                  definition.attributes.values +
                  definition.attribute_groups.values +
                  definition.groups.values

      all_nodes.each do |node|
        expect(node.xml_node).to be_nil
      end
    end

    it 'preserves metadata accessors' do
      definition = new_definition('
        <xs:schema targetNamespace="http://example.com"
                   elementFormDefault="qualified"
                   xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="User" type="xs:string"/>
        </xs:schema>
      ')

      definition.release_dom_references!

      expect(definition.target_namespace).to eq('http://example.com')
      expect(definition.element_form_default).to eq('qualified')
      expect(definition.elements.keys).to eq(['User'])
    end
  end
end
