# frozen_string_literal: true

require 'spec_helper'

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

      it 'raises ResourceLimitError when nesting depth exceeds limit' do
        low_limit = WSDL::Limits.new(max_type_nesting_depth: 2)
        builder = described_class.new(nested_schemas, limits: low_limit)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        expect {
          builder.build([part])
        }.to raise_error(WSDL::ResourceLimitError, /nesting depth.*exceeds limit/)
      end

      it 'includes limit details in the error' do
        low_limit = WSDL::Limits.new(max_type_nesting_depth: 2)
        builder = described_class.new(nested_schemas, limits: low_limit)

        part = {
          element: 'tns:Root',
          namespaces: { 'xmlns:tns' => 'http://example.com/nested' }
        }

        expect {
          builder.build([part])
        }.to raise_error(WSDL::ResourceLimitError) { |e|
          expect(e.limit_name).to eq(:max_type_nesting_depth)
          expect(e.limit_value).to eq(2)
        }
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

      it 'uses WSDL.limits by default' do
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

      it 'passes limits to type.elements for validation' do
        # Set a very low element limit
        low_limit = WSDL::Limits.new(max_elements_per_type: 1)
        builder = described_class.new(simple_schemas, limits: low_limit)

        part = {
          element: 'tns:Simple',
          namespaces: { 'xmlns:tns' => 'http://example.com/simple' }
        }

        expect {
          builder.build([part])
        }.to raise_error(WSDL::ResourceLimitError, /Element count.*exceeds limit/)
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

    it 'raises typed error when referenced schema namespace is missing' do
      builder = described_class.new(test_schemas)

      part = {
        element: 'other:TestElement',
        namespaces: { 'xmlns:other' => 'http://example.com/other' }
      }

      expect {
        builder.build([part])
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:schema_namespace)
        expect(error.namespace).to eq('http://example.com/other')
      }
    end

    it 'raises typed error when referenced element is missing in schema' do
      builder = described_class.new(test_schemas)

      part = {
        element: 'tns:MissingElement',
        namespaces: { 'xmlns:tns' => 'http://example.com/test' }
      }

      expect {
        builder.build([part])
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:element)
        expect(error.reference_name).to eq('MissingElement')
        expect(error.namespace).to eq('http://example.com/test')
      }
    end

    it 'raises typed error when referenced custom type is missing in schema' do
      builder = described_class.new(test_schemas)

      part = {
        name: 'payload',
        type: 'tns:MissingType',
        namespaces: { 'xmlns:tns' => 'http://example.com/test' }
      }

      expect {
        builder.build([part])
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:type)
        expect(error.reference_name).to eq('MissingType')
        expect(error.namespace).to eq('http://example.com/test')
      }
    end

    it 'returns empty array for empty parts' do
      builder = described_class.new(test_schemas)

      elements = builder.build([])

      expect(elements).to eq([])
    end
  end
end
