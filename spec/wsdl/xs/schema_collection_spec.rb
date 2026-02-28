# frozen_string_literal: true

require 'spec_helper'

describe WSDL::XS::SchemaCollection do
  subject(:collection) { described_class.new }

  let(:mock_schema) do
    instance_double(
      WSDL::XS::Schema,
      target_namespace: 'http://example.com/test',
      elements: { 'TestElement' => :element },
      complex_types: { 'TestType' => :complex_type },
      simple_types: { 'TestSimple' => :simple_type },
      attributes: { 'TestAttr' => :attribute },
      attribute_groups: { 'TestAttrGroup' => :attribute_group }
    )
  end

  before do
    collection << mock_schema
  end

  describe '#element' do
    context 'when schema is found' do
      it 'returns the element' do
        expect(collection.element('http://example.com/test', 'TestElement')).to eq(:element)
      end

      it 'returns nil for unknown element name' do
        expect(collection.element('http://example.com/test', 'Unknown')).to be_nil
      end
    end

    context 'when namespace is nil' do
      it 'raises a helpful error mentioning missing default namespace' do
        expect { collection.element(nil, 'Foo') }.to raise_error(
          RuntimeError,
          /Unable to find element 'Foo' - no schema found for namespace nil/
        )
      end

      it 'includes hint about xmlns declaration' do
        expect { collection.element(nil, 'Foo') }.to raise_error(
          RuntimeError,
          /element reference without a namespace prefix.*doesn't define a default namespace/
        )
      end
    end

    context 'when namespace is not found' do
      it 'raises a helpful error with the namespace' do
        expect { collection.element('http://unknown.com', 'Bar') }.to raise_error(
          RuntimeError,
          %r{Unable to find element 'Bar' - no schema found for namespace "http://unknown.com"}
        )
      end

      it 'lists available namespaces' do
        expect { collection.element('http://unknown.com', 'Bar') }.to raise_error(
          RuntimeError,
          %r{Available namespaces: "http://example.com/test"}
        )
      end
    end
  end

  describe '#complex_type' do
    context 'when schema is found' do
      it 'returns the complex type' do
        expect(collection.complex_type('http://example.com/test', 'TestType')).to eq(:complex_type)
      end
    end

    context 'when namespace is nil' do
      it 'raises a helpful error' do
        expect { collection.complex_type(nil, 'MyType') }.to raise_error(
          RuntimeError,
          /Unable to find complexType 'MyType' - no schema found for namespace nil/
        )
      end
    end

    context 'when namespace is not found' do
      it 'raises a helpful error with available namespaces' do
        expect { collection.complex_type('http://missing.com', 'MyType') }.to raise_error(
          RuntimeError,
          /Unable to find complexType 'MyType'.*Available namespaces:/
        )
      end
    end
  end

  describe '#simple_type' do
    context 'when schema is found' do
      it 'returns the simple type' do
        expect(collection.simple_type('http://example.com/test', 'TestSimple')).to eq(:simple_type)
      end
    end

    context 'when namespace is nil' do
      it 'raises a helpful error' do
        expect { collection.simple_type(nil, 'MySimple') }.to raise_error(
          RuntimeError,
          /Unable to find simpleType 'MySimple' - no schema found for namespace nil/
        )
      end
    end
  end

  describe '#attribute' do
    context 'when schema is found' do
      it 'returns the attribute' do
        expect(collection.attribute('http://example.com/test', 'TestAttr')).to eq(:attribute)
      end
    end

    context 'when namespace is nil' do
      it 'raises a helpful error' do
        expect { collection.attribute(nil, 'MyAttr') }.to raise_error(
          RuntimeError,
          /Unable to find attribute 'MyAttr' - no schema found for namespace nil/
        )
      end
    end
  end

  describe '#attribute_group' do
    context 'when schema is found' do
      it 'returns the attribute group' do
        expect(collection.attribute_group('http://example.com/test', 'TestAttrGroup')).to eq(:attribute_group)
      end
    end

    context 'when namespace is nil' do
      it 'raises a helpful error' do
        expect { collection.attribute_group(nil, 'MyGroup') }.to raise_error(
          RuntimeError,
          /Unable to find attributeGroup 'MyGroup' - no schema found for namespace nil/
        )
      end
    end
  end

  describe '#find_by_namespace' do
    it 'returns the schema with matching namespace' do
      expect(collection.find_by_namespace('http://example.com/test')).to eq(mock_schema)
    end

    it 'returns nil for unknown namespace' do
      expect(collection.find_by_namespace('http://unknown.com')).to be_nil
    end

    it 'returns nil for nil namespace' do
      expect(collection.find_by_namespace(nil)).to be_nil
    end
  end

  context 'with multiple schemas' do
    let(:second_schema) do
      instance_double(
        WSDL::XS::Schema,
        target_namespace: 'http://example.com/other',
        elements: { 'OtherElement' => :other_element }
      )
    end

    before do
      collection << second_schema
    end

    it 'lists all available namespaces in error message' do
      expect { collection.element('http://missing.com', 'Test') }.to raise_error(
        RuntimeError,
        %r{Available namespaces:.*"http://example.com/test".*"http://example.com/other"}
      )
    end
  end

  context 'with empty collection' do
    subject(:empty_collection) { described_class.new }

    it 'shows (none) for available namespaces' do
      expect { empty_collection.element('http://any.com', 'Test') }.to raise_error(
        RuntimeError,
        /Available namespaces: \(none\)/
      )
    end
  end
end
