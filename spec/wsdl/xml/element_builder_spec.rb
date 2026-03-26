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
        expect(issues.first[:type]).to eq(:resource_limit)
        expect(issues.first[:error]).to match(/nesting depth.*exceeds limit/)
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

      it 'allows nesting when depth is within limit' do
        generous_limit = WSDL::Limits.new(max_type_nesting_depth: 50)
        builder = described_class.new(nested_schemas, limits: generous_limit)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        expect { builder.build([part]) }.not_to raise_error
      end

      it 'allows unlimited nesting when limit is nil' do
        unlimited = WSDL::Limits.new(max_type_nesting_depth: nil)
        builder = described_class.new(nested_schemas, limits: unlimited)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        expect { builder.build([part]) }.not_to raise_error
      end

      it 'uses Limits defaults when none provided' do
        builder = described_class.new(nested_schemas)

        # Default limits should allow normal nesting (50 levels)
        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        expect { builder.build([part]) }.not_to raise_error
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

        limit_issues = issues.select { |i| i[:type] == :resource_limit }
        expect(limit_issues).not_to be_empty
        expect(limit_issues.first[:error]).to match(/Element count.*exceeds limit/)
      end

      it 'allows elements when within limit' do
        generous_limit = WSDL::Limits.new(max_elements_per_type: 100)
        builder = described_class.new(simple_schemas, limits: generous_limit)

        part = {
          element: 'tns:Simple',
          namespaces: { 'xmlns:tns' => 'http://example.com/simple' }
        }

        expect { builder.build([part]) }.not_to raise_error
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
      expect(issues.first[:type]).to eq(:build_error)
      expect(issues.first[:error]).to match(/Unable to find element/)
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
      expect(issues.first[:type]).to eq(:build_error)
      expect(issues.first[:error]).to match(/Unable to find element/)
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
      expect(issues.first[:type]).to eq(:build_error)
      expect(issues.first[:error]).to match(/Unable to find type/)
    end

    it 'returns empty array for empty parts' do
      builder = described_class.new(test_schemas)

      elements = builder.build([])

      expect(elements).to eq([])
    end
  end
end
