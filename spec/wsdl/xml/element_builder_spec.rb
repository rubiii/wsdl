# frozen_string_literal: true

RSpec.describe WSDL::XML::ElementBuilder do
  let(:schemas) { WSDL::Schema::Collection.new }

  describe 'resource limits' do
    describe 'max_type_nesting_depth' do
      let(:nested_schemas) do
        # Create a schema with deeply nested types
        xml = <<~XML
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     xmlns:tns="http://example.com/nested"
                     targetNamespace="http://example.com/nested"
                     elementFormDefault="qualified">

            <xs:complexType name="Level1Type">
              <xs:sequence>
                <xs:element name="level2" type="tns:Level2Type"/>
              </xs:sequence>
            </xs:complexType>

            <xs:complexType name="Level2Type">
              <xs:sequence>
                <xs:element name="level3" type="tns:Level3Type"/>
              </xs:sequence>
            </xs:complexType>

            <xs:complexType name="Level3Type">
              <xs:sequence>
                <xs:element name="level4" type="tns:Level4Type"/>
              </xs:sequence>
            </xs:complexType>

            <xs:complexType name="Level4Type">
              <xs:sequence>
                <xs:element name="level5" type="tns:Level5Type"/>
              </xs:sequence>
            </xs:complexType>

            <xs:complexType name="Level5Type">
              <xs:sequence>
                <xs:element name="value" type="xs:string"/>
              </xs:sequence>
            </xs:complexType>

            <xs:element name="Root" type="tns:Level1Type"/>
          </xs:schema>
        XML

        collection = WSDL::Schema::Collection.new
        doc = Nokogiri::XML(xml)
        definition = WSDL::Schema::Definition.new(doc.root, collection)
        collection.push([definition])
        collection
      end

      it 'records resource_limit issue when nesting depth exceeds limit' do
        issues = []
        low_limit = WSDL::Limits.new(max_type_nesting_depth: 2)
        builder = described_class.new(nested_schemas, limits: low_limit, issues:)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        builder.build([part])

        expect(issues).not_to be_empty
        expect(issues.first['type']).to eq('resource_limit')
        expect(issues.first['error']).to match(/nesting depth.*exceeds limit/)
      end

      it 'returns partial results when nesting depth is exceeded' do
        issues = []
        low_limit = WSDL::Limits.new(max_type_nesting_depth: 2)
        builder = described_class.new(nested_schemas, limits: low_limit, issues:)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        elements = builder.build([part])
        expect(elements.size).to eq(1)
        expect(elements.first.name).to eq('Root')
      end

      it 'builds full element tree when depth is within limit' do
        generous_limit = WSDL::Limits.new(max_type_nesting_depth: 50)
        builder = described_class.new(nested_schemas, limits: generous_limit)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        elements = builder.build([part])

        expect(elements.size).to eq(1)
        root = elements.first
        expect(root.name).to eq('Root')
        expect(root.children.first.name).to eq('level2')
        expect(root.children.first.children.first.name).to eq('level3')
      end

      it 'resolves every nesting level when limit is nil (unlimited)' do
        unlimited = WSDL::Limits.new(max_type_nesting_depth: nil)
        builder = described_class.new(nested_schemas, limits: unlimited)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        elements = builder.build([part])

        node = elements.first
        %w[level2 level3 level4 level5 value].each do |name|
          node = node.children.first
          expect(node.name).to eq(name)
        end
        expect(node.base_type).to eq('xs:string')
        expect(node.children).to be_empty
      end

      it 'builds element tree with default Limits' do
        builder = described_class.new(nested_schemas)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        elements = builder.build([part])

        expect(elements.size).to eq(1)
        expect(elements.first.name).to eq('Root')
        expect(elements.first.children).not_to be_empty
      end
    end

    describe 'element limits' do
      let(:simple_schemas) do
        xml = <<~XML
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     xmlns:tns="http://example.com/simple"
                     targetNamespace="http://example.com/simple"
                     elementFormDefault="qualified">

            <xs:complexType name="SimpleType">
              <xs:sequence>
                <xs:element name="field1" type="xs:string"/>
                <xs:element name="field2" type="xs:string"/>
              </xs:sequence>
            </xs:complexType>

            <xs:element name="Simple" type="tns:SimpleType"/>
          </xs:schema>
        XML

        collection = WSDL::Schema::Collection.new
        doc = Nokogiri::XML(xml)
        definition = WSDL::Schema::Definition.new(doc.root, collection)
        collection.push([definition])
        collection
      end

      it 'records resource_limit issue when element count exceeds limit' do
        issues = []
        low_limit = WSDL::Limits.new(max_elements_per_type: 1)
        builder = described_class.new(simple_schemas, limits: low_limit, issues:)

        part = {
          element: 'tns:Simple',
          namespaces: { 'xmlns:tns' => 'http://example.com/simple' }
        }

        builder.build([part])

        limit_issues = issues.select { |i| i['type'] == 'resource_limit' }
        expect(limit_issues).not_to be_empty
        expect(limit_issues.first['error']).to match(/Element count.*exceeds limit/)
      end

      it 'builds all child elements when within limit' do
        generous_limit = WSDL::Limits.new(max_elements_per_type: 100)
        builder = described_class.new(simple_schemas, limits: generous_limit)

        part = {
          element: 'tns:Simple',
          namespaces: { 'xmlns:tns' => 'http://example.com/simple' }
        }

        elements = builder.build([part])

        expect(elements.size).to eq(1)
        expect(elements.first.name).to eq('Simple')
        expect(elements.first.children.map(&:name)).to eq(%w[field1 field2])
      end
    end
  end

  describe '#build' do
    let(:test_schemas) do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/test"
                   targetNamespace="http://example.com/test"
                   elementFormDefault="qualified">

          <xs:complexType name="TestType">
            <xs:sequence>
              <xs:element name="name" type="xs:string"/>
            </xs:sequence>
          </xs:complexType>

          <xs:element name="TestElement" type="tns:TestType"/>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])
      collection
    end

    it 'builds elements from parts with element reference' do
      builder = described_class.new(test_schemas)

      part = {
        element: 'tns:TestElement',
        namespaces: { 'xmlns:tns' => 'http://example.com/test' }
      }

      elements = builder.build([part])

      expect(elements.size).to eq(1)
      expect(elements.first.name).to eq('TestElement')
    end

    it 'records build_error when referenced schema namespace is missing' do
      issues = []
      builder = described_class.new(test_schemas, issues:)

      part = {
        element: 'other:TestElement',
        namespaces: { 'xmlns:other' => 'http://example.com/other' }
      }

      elements = builder.build([part])

      expect(elements).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first['type']).to eq('build_error')
      expect(issues.first['error']).to match(/Unable to find element/)
    end

    it 'records build_error when referenced element is missing in schema' do
      issues = []
      builder = described_class.new(test_schemas, issues:)

      part = {
        element: 'tns:MissingElement',
        namespaces: { 'xmlns:tns' => 'http://example.com/test' }
      }

      elements = builder.build([part])

      expect(elements).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first['type']).to eq('build_error')
      expect(issues.first['error']).to match(/Unable to find element/)
    end

    it 'records build_error when referenced custom type is missing in schema' do
      issues = []
      builder = described_class.new(test_schemas, issues:)

      part = {
        name: 'payload',
        type: 'tns:MissingType',
        namespaces: { 'xmlns:tns' => 'http://example.com/test' }
      }

      elements = builder.build([part])

      expect(elements.size).to eq(1)
      expect(issues).not_to be_empty
      expect(issues.first['type']).to eq('build_error')
      expect(issues.first['error']).to match(/Unable to find type/)
    end

    it 'returns empty array for empty parts' do
      builder = described_class.new(test_schemas)

      elements = builder.build([])

      expect(elements).to eq([])
    end
  end

  describe 'SOAP encoding type resolution' do
    let(:soap_enc_schemas) do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/soapenc"
                   xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
                   targetNamespace="http://example.com/soapenc"
                   elementFormDefault="qualified">

          <xs:complexType name="SoapEncTestType">
            <xs:sequence>
              <xs:element name="field1" type="soapenc:string"/>
              <xs:element name="field2" type="soapenc:boolean"/>
              <xs:element name="field3" type="soapenc:Array"/>
            </xs:sequence>
          </xs:complexType>

          <xs:element name="SoapEncTest" type="tns:SoapEncTestType"/>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])
      collection
    end

    it 'resolves soapenc:string as a built-in type' do
      builder = described_class.new(soap_enc_schemas)

      part = {
        element: 'tns:SoapEncTest',
        namespaces: { 'xmlns:tns' => 'http://example.com/soapenc' }
      }

      elements = builder.build([part])
      root = elements.first
      field1 = root.children.find { |c| c.name == 'field1' }

      expect(field1).not_to be_nil
      expect(field1.base_type).to eq('soapenc:string')
    end

    it 'resolves soapenc:boolean as a built-in type' do
      builder = described_class.new(soap_enc_schemas)

      part = {
        element: 'tns:SoapEncTest',
        namespaces: { 'xmlns:tns' => 'http://example.com/soapenc' }
      }

      elements = builder.build([part])
      root = elements.first
      field2 = root.children.find { |c| c.name == 'field2' }

      expect(field2).not_to be_nil
      expect(field2.base_type).to eq('soapenc:boolean')
    end

    it 'resolves soapenc:Array as a built-in type' do
      builder = described_class.new(soap_enc_schemas)

      part = {
        element: 'tns:SoapEncTest',
        namespaces: { 'xmlns:tns' => 'http://example.com/soapenc' }
      }

      elements = builder.build([part])
      root = elements.first
      field3 = root.children.find { |c| c.name == 'field3' }

      expect(field3).not_to be_nil
      expect(field3.base_type).to eq('soapenc:Array')
    end

    it 'records build_error for unknown SOAP encoding types' do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/soapenc-bogus"
                   xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
                   targetNamespace="http://example.com/soapenc-bogus"
                   elementFormDefault="qualified">

          <xs:complexType name="BogusType">
            <xs:sequence>
              <xs:element name="bad" type="soapenc:bogus"/>
            </xs:sequence>
          </xs:complexType>

          <xs:element name="BogusTest" type="tns:BogusType"/>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])

      issues = []
      builder = described_class.new(collection, issues:)

      part = {
        element: 'tns:BogusTest',
        namespaces: { 'xmlns:tns' => 'http://example.com/soapenc-bogus' }
      }

      builder.build([part])

      expect(issues).not_to be_empty
      expect(issues.first['type']).to eq('build_error')
      expect(issues.first['error']).to match(/Unknown SOAP encoding type/)
    end

    it 'resolves SOAP 1.2 encoding namespace types as built-ins' do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/soapenc12"
                   xmlns:enc12="http://www.w3.org/2003/05/soap-encoding"
                   targetNamespace="http://example.com/soapenc12"
                   elementFormDefault="qualified">

          <xs:complexType name="Enc12Type">
            <xs:sequence>
              <xs:element name="value" type="enc12:string"/>
            </xs:sequence>
          </xs:complexType>

          <xs:element name="Enc12Test" type="tns:Enc12Type"/>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])

      builder = described_class.new(collection)

      part = {
        element: 'tns:Enc12Test',
        namespaces: { 'xmlns:tns' => 'http://example.com/soapenc12' }
      }

      elements = builder.build([part])
      root = elements.first
      value = root.children.find { |c| c.name == 'value' }

      expect(value).not_to be_nil
      expect(value.base_type).to eq('enc12:string')
    end
  end

  describe 'element ref recursion detection' do
    let(:recursive_ref_schemas) do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/refcycle"
                   targetNamespace="http://example.com/refcycle"
                   elementFormDefault="qualified">

          <xs:element name="Item">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="Title" type="xs:string"/>
                <xs:element ref="tns:RelatedItems" minOccurs="0"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>

          <xs:element name="RelatedItems">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="tns:Item" minOccurs="0" maxOccurs="unbounded"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>

          <xs:element name="ItemLookupResponse">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="tns:Item"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])
      collection
    end

    it 'detects cyclic element refs and sets recursive_type' do
      builder = described_class.new(recursive_ref_schemas)

      part = {
        element: 'tns:ItemLookupResponse',
        namespaces: { 'xmlns:tns' => 'http://example.com/refcycle' }
      }

      elements = builder.build([part])
      root = elements.first

      # ItemLookupResponse -> Item -> RelatedItems -> Item (cycle)
      item = root.children.find { |c| c.name == 'Item' }
      expect(item).not_to be_nil
      expect(item.children).not_to be_empty

      related_items = item.children.find { |c| c.name == 'RelatedItems' }
      expect(related_items).not_to be_nil

      # The second Item reference should be detected as recursive
      recursive_item = related_items.children.find { |c| c.name == 'Item' }
      expect(recursive_item).not_to be_nil
      expect(recursive_item).to be_recursive
      expect(recursive_item.recursive_type).to eq('tns:Item')
      expect(recursive_item.children).to be_empty
    end

    it 'does not falsely detect non-cyclic element refs as recursive' do
      xml = <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                   xmlns:tns="http://example.com/norecurse"
                   targetNamespace="http://example.com/norecurse"
                   elementFormDefault="qualified">

          <xs:element name="Address">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="Street" type="xs:string"/>
                <xs:element name="City" type="xs:string"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>

          <xs:element name="Person">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="Name" type="xs:string"/>
                <xs:element ref="tns:Address"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>

          <xs:element name="PersonLookup">
            <xs:complexType>
              <xs:sequence>
                <xs:element ref="tns:Person"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XML

      collection = WSDL::Schema::Collection.new
      doc = Nokogiri::XML(xml)
      definition = WSDL::Schema::Definition.new(doc.root, collection)
      collection.push([definition])

      builder = described_class.new(collection)

      part = {
        element: 'tns:PersonLookup',
        namespaces: { 'xmlns:tns' => 'http://example.com/norecurse' }
      }

      elements = builder.build([part])
      root = elements.first

      person = root.children.find { |c| c.name == 'Person' }
      expect(person).not_to be_recursive

      address = person.children.find { |c| c.name == 'Address' }
      expect(address).not_to be_recursive
      expect(address.children.map(&:name)).to eq(%w[Street City])
    end

    it 'uses the ref QName as the recursive_type label' do
      builder = described_class.new(recursive_ref_schemas)

      part = {
        element: 'tns:ItemLookupResponse',
        namespaces: { 'xmlns:tns' => 'http://example.com/refcycle' }
      }

      elements = builder.build([part])
      root = elements.first

      item = root.children.find { |c| c.name == 'Item' }
      related_items = item.children.find { |c| c.name == 'RelatedItems' }
      recursive_item = related_items.children.find { |c| c.name == 'Item' }

      # The label should be the original ref QName, not nil or a resolved URI
      expect(recursive_item.recursive_type).to eq('tns:Item')
    end
  end
end
