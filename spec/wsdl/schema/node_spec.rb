# frozen_string_literal: true

RSpec.describe WSDL::Schema::Node do
  def new_node(xml, collection = nil, context = {})
    node = Nokogiri.XML(xml).root
    described_class.new(node, collection, context)
  end

  describe '#kind' do
    it 'returns the element type as a symbol' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.kind).to eq(:element)
    end

    it 'returns :complexType for complex type nodes' do
      node = new_node('<xs:complexType name="TestType" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.kind).to eq(:complexType)
    end

    it 'returns :simpleType for simple type nodes' do
      node = new_node('<xs:simpleType name="TestType" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.kind).to eq(:simpleType)
    end

    it 'returns :sequence for sequence nodes' do
      node = new_node('<xs:sequence xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.kind).to eq(:sequence)
    end

    it 'returns :any for xs:any wildcards' do
      node = new_node('<xs:any xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.kind).to eq(:any)
    end
  end

  describe '#name' do
    it 'returns the name attribute' do
      node = new_node('<xs:element name="UserName" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.name).to eq('UserName')
    end

    it 'returns nil when no name attribute exists' do
      node = new_node('<xs:sequence xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.name).to be_nil
    end
  end

  describe '#type' do
    it 'returns the type attribute' do
      node = new_node('<xs:element name="age" type="xs:int" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.type).to eq('xs:int')
    end

    it 'returns nil when no type attribute exists' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.type).to be_nil
    end
  end

  describe '#ref' do
    it 'returns the ref attribute' do
      node = new_node('<xs:element ref="tns:User" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.ref).to eq('tns:User')
    end

    it 'returns nil when no ref attribute exists' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.ref).to be_nil
    end
  end

  describe '#base' do
    it 'returns the base attribute' do
      node = new_node('<xs:extension base="tns:BaseType" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.base).to eq('tns:BaseType')
    end

    it 'returns nil when no base attribute exists' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.base).to be_nil
    end
  end

  describe '#use' do
    it 'returns the use attribute value' do
      node = new_node('<xs:attribute name="id" use="required" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.use).to eq('required')
    end

    it 'defaults to optional when not specified' do
      node = new_node('<xs:attribute name="id" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.use).to eq('optional')
    end
  end

  describe '#default' do
    it 'returns the default attribute value' do
      node = new_node('<xs:attribute name="status" default="active" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.default).to eq('active')
    end

    it 'returns nil when no default is specified' do
      node = new_node('<xs:attribute name="status" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.default).to be_nil
    end
  end

  describe '#fixed' do
    it 'returns the fixed attribute value' do
      node = new_node('<xs:attribute name="version" fixed="1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.fixed).to eq('1.0')
    end

    it 'returns nil when no fixed value is specified' do
      node = new_node('<xs:attribute name="version" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.fixed).to be_nil
    end
  end

  describe '#nillable?' do
    it 'returns true when nillable is "true"' do
      node = new_node('<xs:element name="test" nillable="true" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.nillable?).to be true
    end

    it 'returns false when nillable is "false"' do
      node = new_node('<xs:element name="test" nillable="false" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.nillable?).to be false
    end

    it 'returns false when nillable is not specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.nillable?).to be false
    end
  end

  describe '#namespace' do
    it 'returns the target namespace from context' do
      context = { target_namespace: 'http://example.com/ns' }
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil, context)
      expect(node.namespace).to eq('http://example.com/ns')
    end

    it 'returns nil when no target namespace in context' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.namespace).to be_nil
    end
  end

  describe '#form' do
    it 'returns the explicit form attribute' do
      node = new_node('<xs:element name="test" form="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.form).to eq('qualified')
    end

    it 'returns qualified when elementFormDefault is qualified' do
      context = { element_form_default: 'qualified' }
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil, context)
      expect(node.form).to eq('qualified')
    end

    it 'returns unqualified when elementFormDefault is unqualified' do
      context = { element_form_default: 'unqualified' }
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil, context)
      expect(node.form).to eq('unqualified')
    end

    it 'defaults to unqualified when no form or elementFormDefault specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.form).to eq('unqualified')
    end
  end

  describe '#[]' do
    it 'accesses any attribute by name' do
      node = new_node('<xs:element name="test" minOccurs="0" maxOccurs="unbounded" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node['minOccurs']).to eq('0')
      expect(node['maxOccurs']).to eq('unbounded')
    end

    it 'returns nil for non-existent attributes' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node['nonexistent']).to be_nil
    end
  end

  describe 'attribute caching' do
    it 'returns the same object on repeated reads for present attributes' do
      node = new_node('<xs:element name="test" type="xs:int" ref="tns:Foo"
                                   default="x" fixed="y"
                                   xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      expect(node.name).to equal(node.name)
      expect(node.type).to equal(node.type)
      expect(node.ref).to equal(node.ref)
      expect(node.default).to equal(node.default)
      expect(node.fixed).to equal(node.fixed)
    end

    it 'returns the same object for base attribute' do
      node = new_node('<xs:extension base="tns:BaseType" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      expect(node.base).to equal(node.base)
    end

    it 'caches nil when the attribute is absent' do
      node = new_node('<xs:element xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      # Nokogiri allocates a new String per Node#[] call, so we can verify
      # caching by checking that the underlying node is only queried once.
      xml_node = node.xml_node
      allow(xml_node).to receive(:[]).and_call_original

      node.name
      node.name
      node.type
      node.type

      expect(xml_node).to have_received(:[]).with('name').once
      expect(xml_node).to have_received(:[]).with('type').once
    end

    it 'returns the same object for attributes with defaults' do
      node = new_node('<xs:element name="test" maxOccurs="unbounded" minOccurs="0"
                                   xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      expect(node.max_occurs).to equal(node.max_occurs)
      expect(node.min_occurs).to equal(node.min_occurs)
    end

    it 'returns the same object for use and form' do
      node = new_node('<xs:attribute name="x" use="required" form="qualified"
                                     xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      expect(node.use).to equal(node.use)
      expect(node.form).to equal(node.form)
    end

    it 'caches the nillable boolean' do
      node = new_node('<xs:element name="test" nillable="true" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      xml_node = node.xml_node
      allow(xml_node).to receive(:[]).and_call_original

      node.nillable?
      node.nillable?

      expect(xml_node).to have_received(:[]).with('nillable').once
    end

    it 'returns the same object for wildcard attributes' do
      node = new_node('<xs:any namespace="##other" processContents="lax"
                                xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      expect(node.namespace_constraint).to equal(node.namespace_constraint)
      expect(node.process_contents).to equal(node.process_contents)
    end
  end

  describe '#namespaces' do
    it 'returns namespace declarations in scope' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tns="http://example.com"/>')
      expect(node.namespaces).to include('xmlns:xs' => 'http://www.w3.org/2001/XMLSchema')
      expect(node.namespaces).to include('xmlns:tns' => 'http://example.com')
    end

    it 'returns frozen hash' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.namespaces).to be_frozen
    end
  end

  describe '#children' do
    it 'returns parsed child nodes' do
      node = new_node('
        <xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="name" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
      ')

      expect(node.children.count).to eq(1)
      expect(node.children.first.kind).to eq(:sequence)
    end

    it 'returns empty array when no children exist' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.children).to eq([])
    end

    it 'inherits context to child nodes' do
      context = { target_namespace: 'http://example.com', element_form_default: 'qualified' }
      node = new_node('
        <xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="name" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
      ', nil, context)

      sequence = node.children.first
      element = sequence.children.first
      expect(element.namespace).to eq('http://example.com')
      expect(element.form).to eq('qualified')
    end
  end

  describe '#empty?' do
    it 'returns true when no children exist' do
      node = new_node('<xs:sequence xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.empty?).to be true
    end

    it 'returns false when children exist' do
      node = new_node('
        <xs:sequence xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="test" type="xs:string"/>
        </xs:sequence>
      ')
      expect(node.empty?).to be false
    end
  end

  describe '#elements' do
    it 'collects element children from sequence' do
      node = new_node('
        <xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="name" type="xs:string"/>
            <xs:element name="age" type="xs:int"/>
          </xs:sequence>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements.count).to eq(2)
      expect(elements.map(&:name)).to eq(%w[name age])
      expect(elements).to all(satisfy { |e| e.kind == :element })
    end

    it 'collects element children from all compositor' do
      node = new_node('
        <xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:all>
            <xs:element name="first" type="xs:string"/>
            <xs:element name="second" type="xs:string"/>
          </xs:all>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements.count).to eq(2)
    end

    it 'collects element children from choice compositor' do
      node = new_node('
        <xs:complexType name="Identifier" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:choice>
            <xs:element name="id" type="xs:int"/>
            <xs:element name="uuid" type="xs:string"/>
          </xs:choice>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements.count).to eq(2)
    end

    it 'collects xs:any wildcards' do
      node = new_node('
        <xs:complexType name="Extensible" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="fixed" type="xs:string"/>
            <xs:any namespace="##any" processContents="lax"/>
          </xs:sequence>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements.count).to eq(2)
      expect(elements[0].kind).to eq(:element)
      expect(elements[1].kind).to eq(:any)
    end

    it 'stops at annotation terminators' do
      node = new_node('
        <xs:complexType name="Documented" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:annotation>
            <xs:documentation>This should not be traversed</xs:documentation>
          </xs:annotation>
          <xs:sequence>
            <xs:element name="value" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements.count).to eq(1)
      expect(elements.first.name).to eq('value')
    end

    it 'stops at simpleContent terminators' do
      node = new_node('
        <xs:complexType name="SimpleWrapper" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleContent>
            <xs:extension base="xs:string">
              <xs:attribute name="unit" type="xs:string"/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>
      ')

      elements = node.elements
      expect(elements).to be_empty
    end

    it 'stops at attribute terminators' do
      node = new_node('<xs:attribute name="test" type="xs:string" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.elements).to be_empty
    end

    context 'with extensions' do
      let(:base_type) do
        new_node('
          <xs:complexType name="BaseType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="baseField" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        ')
      end

      let(:collection) do
        instance_double(WSDL::Schema::Collection).tap do |c|
          allow(c).to receive(:find_type)
            .with('http://example.com', 'BaseType')
            .and_return(base_type)
        end
      end

      it 'includes elements from base type' do
        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType name="DerivedType" xmlns:xs="http://www.w3.org/2001/XMLSchema"
                                             xmlns:tns="http://example.com">
            <xs:complexContent>
              <xs:extension base="tns:BaseType">
                <xs:sequence>
                  <xs:element name="derivedField" type="xs:int"/>
                </xs:sequence>
              </xs:extension>
            </xs:complexContent>
          </xs:complexType>
        ', collection, context)

        elements = node.elements
        expect(elements.count).to eq(2)
        expect(elements.map(&:name)).to eq(%w[baseField derivedField])
      end

      it 'skips unresolvable base type and preserves own elements' do
        unresolved_collection = instance_double(WSDL::Schema::Collection)
        allow(unresolved_collection).to receive(:find_type).and_return(nil)

        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType name="DerivedType" xmlns:xs="http://www.w3.org/2001/XMLSchema"
                                             xmlns:tns="http://example.com">
            <xs:complexContent>
              <xs:extension base="tns:MissingType">
                <xs:sequence>
                  <xs:element name="derivedField" type="xs:int"/>
                </xs:sequence>
              </xs:extension>
            </xs:complexContent>
          </xs:complexType>
        ', unresolved_collection, context)

        elements = node.elements
        expect(elements.map(&:name)).to eq(%w[derivedField])
      end
    end

    context 'with group references' do
      let(:group) do
        new_node('
          <xs:group name="AddressGroup" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="street" type="xs:string"/>
              <xs:element name="city" type="xs:string"/>
            </xs:sequence>
          </xs:group>
        ')
      end

      let(:collection) do
        instance_double(WSDL::Schema::Collection).tap do |c|
          allow(c).to receive(:find_group)
            .with('http://example.com', 'AddressGroup')
            .and_return(group)
        end
      end

      it 'resolves group references and expands their elements' do
        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType name="Contact" xmlns:xs="http://www.w3.org/2001/XMLSchema"
                                          xmlns:tns="http://example.com">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
              <xs:group ref="tns:AddressGroup"/>
            </xs:sequence>
          </xs:complexType>
        ', collection, context)

        elements = node.elements
        expect(elements.count).to eq(3)
        expect(elements.map(&:name)).to eq(%w[name street city])
      end
    end

    context 'with unresolvable references' do
      let(:missing_collection) do
        instance_double(WSDL::Schema::Collection).tap do |c|
          allow(c).to receive_messages(find_group: nil, find_type: nil)
        end
      end

      it 'skips unresolvable group refs and preserves sibling elements' do
        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType xmlns:xs="http://www.w3.org/2001/XMLSchema"
                          xmlns:tns="http://example.com">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
              <xs:group ref="tns:Missing"/>
              <xs:element name="email" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        ', missing_collection, context)

        elements = node.elements
        expect(elements.map(&:name)).to eq(%w[name email])
      end

      it 'preserves extension elements when base type is unresolvable' do
        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType xmlns:xs="http://www.w3.org/2001/XMLSchema"
                          xmlns:tns="http://example.com">
            <xs:complexContent>
              <xs:extension base="tns:MissingBase">
                <xs:sequence>
                  <xs:element name="ownField" type="xs:string"/>
                </xs:sequence>
              </xs:extension>
            </xs:complexContent>
          </xs:complexType>
        ', missing_collection, context)

        elements = node.elements
        expect(elements.map(&:name)).to eq(%w[ownField])
      end
    end
  end

  describe '#attributes' do
    it 'collects attribute children' do
      node = new_node('
        <xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:sequence>
            <xs:element name="name" type="xs:string"/>
          </xs:sequence>
          <xs:attribute name="id" type="xs:int"/>
          <xs:attribute name="status" type="xs:string"/>
        </xs:complexType>
      ')

      attributes = node.attributes
      expect(attributes.count).to eq(2)
      expect(attributes.map(&:name)).to eq(%w[id status])
      expect(attributes).to all(satisfy { |a| a.kind == :attribute })
    end

    it 'stops at annotation terminators' do
      node = new_node('
        <xs:complexType name="Documented" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:annotation>
            <xs:documentation>Docs</xs:documentation>
          </xs:annotation>
          <xs:attribute name="value" type="xs:string"/>
        </xs:complexType>
      ')

      attributes = node.attributes
      expect(attributes.count).to eq(1)
      expect(attributes.first.name).to eq('value')
    end

    it 'finds attributes inside simpleContent extensions' do
      node = new_node('
        <xs:simpleContent xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:extension base="xs:string">
            <xs:attribute name="unit" type="xs:string"/>
          </xs:extension>
        </xs:simpleContent>
      ')

      attributes = node.attributes
      expect(attributes.count).to eq(1)
      expect(attributes.first.name).to eq('unit')
    end

    context 'with attributeGroup references' do
      let(:attribute_group) do
        new_node('
          <xs:attributeGroup name="CommonAttrs" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:attribute name="id" type="xs:int"/>
            <xs:attribute name="class" type="xs:string"/>
          </xs:attributeGroup>
        ')
      end

      let(:collection) do
        instance_double(WSDL::Schema::Collection).tap do |c|
          allow(c).to receive(:find_attribute_group)
            .with('http://example.com', 'CommonAttrs')
            .and_return(attribute_group)
        end
      end

      it 'resolves attributeGroup references' do
        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:attributeGroup ref="tns:CommonAttrs" xmlns:xs="http://www.w3.org/2001/XMLSchema"
                                                   xmlns:tns="http://example.com"/>
        ', collection, context)

        attributes = node.attributes
        expect(attributes.count).to eq(2)
        expect(attributes.map(&:name)).to eq(%w[id class])
      end

      it 'skips unresolvable attributeGroup refs and preserves sibling attributes' do
        missing_collection = instance_double(WSDL::Schema::Collection)
        allow(missing_collection).to receive(:find_attribute_group).and_return(nil)

        context = { target_namespace: 'http://example.com' }
        node = new_node('
          <xs:complexType xmlns:xs="http://www.w3.org/2001/XMLSchema"
                          xmlns:tns="http://example.com">
            <xs:attribute name="id" type="xs:int"/>
            <xs:attributeGroup ref="tns:MissingGroup"/>
            <xs:attribute name="status" type="xs:string"/>
          </xs:complexType>
        ', missing_collection, context)

        attributes = node.attributes
        expect(attributes.map(&:name)).to eq(%w[id status])
      end
    end
  end

  describe '#inline_type' do
    it 'returns inline complexType' do
      node = new_node('
        <xs:element name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ')

      inline = node.inline_type
      expect(inline).not_to be_nil
      expect(inline.kind).to eq(:complexType)
    end

    it 'returns inline simpleType' do
      node = new_node('
        <xs:element name="status" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:enumeration value="active"/>
              <xs:enumeration value="inactive"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
      ')

      inline = node.inline_type
      expect(inline).not_to be_nil
      expect(inline.kind).to eq(:simpleType)
    end

    it 'skips annotation elements' do
      node = new_node('
        <xs:element name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:annotation>
            <xs:documentation>User element</xs:documentation>
          </xs:annotation>
          <xs:complexType>
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      ')

      inline = node.inline_type
      expect(inline).not_to be_nil
      expect(inline.kind).to eq(:complexType)
    end

    it 'returns nil when no inline type exists' do
      node = new_node('<xs:element name="test" type="xs:string" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.inline_type).to be_nil
    end
  end

  describe '#restriction_base' do
    it 'returns base from restriction child' do
      node = new_node('
        <xs:simpleType name="Status" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:restriction base="xs:string">
            <xs:enumeration value="active"/>
          </xs:restriction>
        </xs:simpleType>
      ')

      expect(node.restriction_base).to eq('xs:string')
    end

    it 'returns nil when no restriction child' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.restriction_base).to be_nil
    end
  end

  describe '#list_item_type' do
    it 'returns itemType from list child' do
      node = new_node('
        <xs:simpleType name="StringList" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:list itemType="xs:string"/>
        </xs:simpleType>
      ')

      expect(node.list_item_type).to eq('xs:string')
    end

    it 'returns nil when no list child' do
      node = new_node('
        <xs:simpleType name="Status" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:restriction base="xs:string"/>
        </xs:simpleType>
      ')

      expect(node.list_item_type).to be_nil
    end
  end

  describe '#union_member_types' do
    it 'returns memberTypes from union child' do
      node = new_node('
        <xs:simpleType name="StringOrInt" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:union memberTypes="xs:string xs:int"/>
        </xs:simpleType>
      ')

      expect(node.union_member_types).to eq('xs:string xs:int')
    end

    it 'returns nil when no union child' do
      node = new_node('
        <xs:simpleType name="Status" xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:restriction base="xs:string"/>
        </xs:simpleType>
      ')

      expect(node.union_member_types).to be_nil
    end
  end

  describe '#type_id' do
    it 'returns namespace:name for complexType' do
      context = { target_namespace: 'http://example.com' }
      node = new_node('<xs:complexType name="User" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil, context)
      expect(node.type_id).to eq('http://example.com:User')
    end

    it 'returns namespace:name for element' do
      context = { target_namespace: 'http://example.com' }
      node = new_node('<xs:element name="user" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil, context)
      expect(node.type_id).to eq('http://example.com:user')
    end

    it 'returns nil for non-type kinds' do
      node = new_node('<xs:sequence xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.type_id).to be_nil
    end
  end

  describe '#any?' do
    it 'returns true for xs:any nodes' do
      node = new_node('<xs:any xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.any?).to be true
    end

    it 'returns false for other nodes' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.any?).to be false
    end
  end

  describe '#namespace_constraint' do
    it 'returns the namespace attribute for xs:any' do
      node = new_node('<xs:any namespace="##other" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.namespace_constraint).to eq('##other')
    end

    it 'defaults to ##any when not specified' do
      node = new_node('<xs:any xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.namespace_constraint).to eq('##any')
    end
  end

  describe '#process_contents' do
    it 'returns the processContents attribute' do
      node = new_node('<xs:any processContents="lax" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.process_contents).to eq('lax')
    end

    it 'defaults to strict when not specified' do
      node = new_node('<xs:any xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.process_contents).to eq('strict')
    end
  end

  describe '#max_occurs' do
    it 'returns the maxOccurs attribute' do
      node = new_node('<xs:element name="test" maxOccurs="unbounded" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.max_occurs).to eq('unbounded')
    end

    it 'defaults to 1 when not specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.max_occurs).to eq('1')
    end
  end

  describe '#min_occurs' do
    it 'returns the minOccurs attribute' do
      node = new_node('<xs:element name="test" minOccurs="0" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.min_occurs).to eq('0')
    end

    it 'defaults to 1 when not specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.min_occurs).to eq('1')
    end
  end

  describe '#multiple?' do
    it 'returns true when maxOccurs is unbounded' do
      node = new_node('<xs:element name="test" maxOccurs="unbounded" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.multiple?).to be true
    end

    it 'returns true when maxOccurs is greater than 1' do
      node = new_node('<xs:element name="test" maxOccurs="5" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.multiple?).to be true
    end

    it 'returns false when maxOccurs is 1' do
      node = new_node('<xs:element name="test" maxOccurs="1" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.multiple?).to be false
    end

    it 'returns false when maxOccurs is not specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.multiple?).to be false
    end
  end

  describe '#optional?' do
    it 'returns true when minOccurs is 0' do
      node = new_node('<xs:element name="test" minOccurs="0" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.optional?).to be true
    end

    it 'returns false when minOccurs is not 0' do
      node = new_node('<xs:element name="test" minOccurs="1" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.optional?).to be false
    end

    it 'returns false when minOccurs is not specified' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.optional?).to be false
    end
  end

  describe '#required?' do
    it 'returns true when minOccurs is not 0' do
      node = new_node('<xs:element name="test" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.required?).to be true
    end

    it 'returns false when minOccurs is 0' do
      node = new_node('<xs:element name="test" minOccurs="0" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.required?).to be false
    end
  end

  describe '#deconstruct_keys' do
    it 'returns hash with kind, name, type, ref, and namespace' do
      context = { target_namespace: 'http://example.com' }
      node = new_node('<xs:element name="user" type="tns:User" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>', nil,
        context)

      result = node.deconstruct_keys(nil)
      expect(result).to eq({
        kind: :element,
        name: 'user',
        type: 'tns:User',
        ref: nil,
        namespace: 'http://example.com'
      })
    end

    it 'supports Ruby pattern matching' do
      node = new_node('<xs:element name="test" type="xs:string" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')

      result = case node
      in { kind: :element, name: n, type: t }
        "element #{n} with type #{t}"
      else
        'no match'
      end

      expect(result).to eq('element test with type xs:string')
    end
  end

  describe '#inspect' do
    it 'returns formatted debug string' do
      node = new_node('<xs:element name="User" type="tns:UserType" xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      expect(node.inspect).to include('Schema::Node:element')
      expect(node.inspect).to include('name="User"')
      expect(node.inspect).to include('type="tns:UserType"')
    end
  end

  describe 'resource limits' do
    describe 'max_elements_per_type' do
      it 'raises ResourceLimitError when element count exceeds limit' do
        limits = WSDL::Limits.new(max_elements_per_type: 2)

        xml = <<~XML
          <xs:complexType name="LargeType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="field1" type="xs:string"/>
              <xs:element name="field2" type="xs:string"/>
              <xs:element name="field3" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect {
          node.elements([], limits:)
        }.to raise_error(WSDL::ResourceLimitError, /Element count.*exceeds limit/)
      end

      it 'includes limit details in the error' do
        limits = WSDL::Limits.new(max_elements_per_type: 2)

        xml = <<~XML
          <xs:complexType name="LargeType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="field1" type="xs:string"/>
              <xs:element name="field2" type="xs:string"/>
              <xs:element name="field3" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect {
          node.elements([], limits:)
        }.to raise_error(WSDL::ResourceLimitError) { |e|
          expect(e.limit_name).to eq(:max_elements_per_type)
          expect(e.limit_value).to eq(2)
          expect(e.actual_value).to eq(3)
        }
      end

      it 'allows elements when count is within limit' do
        limits = WSDL::Limits.new(max_elements_per_type: 10)

        xml = <<~XML
          <xs:complexType name="SmallType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="field1" type="xs:string"/>
              <xs:element name="field2" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect { node.elements([], limits:) }.not_to raise_error
        expect(node.elements([], limits:).size).to eq(2)
      end

      it 'allows unlimited elements when limit is nil' do
        limits = WSDL::Limits.new(max_elements_per_type: nil)

        xml = <<~XML
          <xs:complexType name="LargeType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="field1" type="xs:string"/>
              <xs:element name="field2" type="xs:string"/>
              <xs:element name="field3" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect { node.elements([], limits:) }.not_to raise_error
      end

      it 'does not check limits when limits parameter is nil' do
        xml = <<~XML
          <xs:complexType name="LargeType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:sequence>
              <xs:element name="field1" type="xs:string"/>
              <xs:element name="field2" type="xs:string"/>
              <xs:element name="field3" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect { node.elements }.not_to raise_error
        expect { node.elements([], limits: nil) }.not_to raise_error
      end
    end

    describe 'max_attributes_per_element' do
      it 'raises ResourceLimitError when attribute count exceeds limit' do
        limits = WSDL::Limits.new(max_attributes_per_element: 2)

        xml = <<~XML
          <xs:complexType name="ManyAttrsType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="attr1" type="xs:string"/>
                <xs:attribute name="attr2" type="xs:string"/>
                <xs:attribute name="attr3" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect {
          node.attributes([], limits:)
        }.to raise_error(WSDL::ResourceLimitError, /Attribute count.*exceeds limit/)
      end

      it 'includes limit details in the error' do
        limits = WSDL::Limits.new(max_attributes_per_element: 2)

        xml = <<~XML
          <xs:complexType name="ManyAttrsType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="attr1" type="xs:string"/>
                <xs:attribute name="attr2" type="xs:string"/>
                <xs:attribute name="attr3" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect {
          node.attributes([], limits:)
        }.to raise_error(WSDL::ResourceLimitError) { |e|
          expect(e.limit_name).to eq(:max_attributes_per_element)
          expect(e.limit_value).to eq(2)
          expect(e.actual_value).to eq(3)
        }
      end

      it 'includes a hint to increase the limit in error message' do
        limits = WSDL::Limits.new(max_attributes_per_element: 2)

        xml = <<~XML
          <xs:complexType name="ManyAttrsType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="attr1" type="xs:string"/>
                <xs:attribute name="attr2" type="xs:string"/>
                <xs:attribute name="attr3" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect {
          node.attributes([], limits:)
        }.to raise_error(WSDL::ResourceLimitError, /limits: \{ max_attributes_per_element: 3 \}/)
      end

      it 'allows attributes when count is within limit' do
        limits = WSDL::Limits.new(max_attributes_per_element: 10)

        xml = <<~XML
          <xs:complexType name="SmallAttrsType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="attr1" type="xs:string"/>
                <xs:attribute name="attr2" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect { node.attributes([], limits:) }.not_to raise_error
        expect(node.attributes([], limits:).size).to eq(2)
      end

      it 'allows unlimited attributes when limit is nil' do
        limits = WSDL::Limits.new(max_attributes_per_element: nil)

        xml = <<~XML
          <xs:complexType name="ManyAttrsType" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <xs:simpleContent>
              <xs:extension base="xs:string">
                <xs:attribute name="attr1" type="xs:string"/>
                <xs:attribute name="attr2" type="xs:string"/>
                <xs:attribute name="attr3" type="xs:string"/>
              </xs:extension>
            </xs:simpleContent>
          </xs:complexType>
        XML

        node = new_node(xml)

        expect { node.attributes([], limits:) }.not_to raise_error
      end
    end
  end
end
