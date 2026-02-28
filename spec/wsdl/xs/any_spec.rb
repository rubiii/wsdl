# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::XS::Any do
  let(:wsdl_path) { 'spec/fixtures/wsdl/amazon.wsdl' }
  let(:wsdl) { WSDL.new(wsdl_path) }
  let(:schemas) { wsdl.wsdl.schemas }
  let(:amazon_namespace) { 'http://fps.amazonaws.com/doc/2008-09-17/' }
  let(:schema) { schemas.find_by_namespace(amazon_namespace) }

  describe 'TYPE_MAPPING' do
    it 'includes the any type' do
      expect(WSDL::XS::TYPE_MAPPING).to include('any' => described_class)
    end
  end

  describe 'parsing xs:any elements' do
    # The Amazon WSDL has an Error element with a Detail child that uses xs:any
    # <xs:element name="Detail" minOccurs="0">
    #   <xs:complexType>
    #     <xs:sequence>
    #       <xs:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
    #     </xs:sequence>
    #   </xs:complexType>
    # </xs:element>

    it 'parses xs:any as WSDL::XS::Any type' do
      # Navigate to the Error element -> Detail element -> complexType -> sequence -> any
      error_element = schema.elements['Error']
      expect(error_element).not_to be_nil

      detail_element = error_element.children.detect { |c| c.is_a?(WSDL::XS::ComplexType) }
        &.children&.detect { |c| c.is_a?(WSDL::XS::Sequence) }
        &.children&.detect { |c| c.is_a?(WSDL::XS::Element) && c.name == 'Detail' }

      expect(detail_element).not_to be_nil

      # The Detail element has an inline complexType with a sequence containing xs:any
      inline_type = detail_element.inline_type
      expect(inline_type).to be_a(WSDL::XS::ComplexType)

      sequence = inline_type.children.detect { |c| c.is_a?(WSDL::XS::Sequence) }
      expect(sequence).not_to be_nil

      any_element = sequence.children.detect { |c| c.is_a?(described_class) }
      expect(any_element).to be_a(described_class)
    end
  end

  describe WSDL::XS::Any do
    let(:any_element) do
      error_element = schema.elements['Error']
      detail_element = error_element.children.detect { |c| c.is_a?(WSDL::XS::ComplexType) }
        &.children&.detect { |c| c.is_a?(WSDL::XS::Sequence) }
        &.children&.detect { |c| c.is_a?(WSDL::XS::Element) && c.name == 'Detail' }
      inline_type = detail_element.inline_type
      sequence = inline_type.children.detect { |c| c.is_a?(WSDL::XS::Sequence) }
      sequence.children.detect { |c| c.is_a?(described_class) }
    end

    describe '#namespace_constraint' do
      it 'returns the namespace attribute value' do
        expect(any_element.namespace_constraint).to eq('##any')
      end
    end

    describe '#process_contents' do
      it 'returns the processContents attribute value' do
        expect(any_element.process_contents).to eq('lax')
      end
    end

    describe '#multiple?' do
      it 'returns true when maxOccurs is unbounded' do
        expect(any_element.multiple?).to be true
      end
    end

    describe '#optional?' do
      it 'returns true when minOccurs is 0' do
        expect(any_element.optional?).to be true
      end
    end

    describe '#collect_child_elements' do
      it 'returns the memo unchanged (wildcards have no predefined children)' do
        memo = [:existing]
        result = any_element.collect_child_elements(memo)
        expect(result).to eq([:existing])
      end
    end
  end
end

RSpec.describe 'xsd:any in XML::Element' do
  let(:wsdl_path) { 'spec/fixtures/wsdl/amazon.wsdl' }
  let(:wsdl) { WSDL.new(wsdl_path) }
  let(:schemas) { wsdl.wsdl.schemas }
  let(:amazon_namespace) { 'http://fps.amazonaws.com/doc/2008-09-17/' }
  let(:schema) { schemas.find_by_namespace(amazon_namespace) }

  describe 'any_content attribute' do
    it 'marks elements with xs:any as allowing arbitrary content' do
      # Build the element tree for the Error element
      builder = WSDL::XML::ElementBuilder.new(schemas)

      # Build an element from the Error definition
      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => amazon_namespace } }
      elements = builder.build([part])

      error_element = elements.first
      expect(error_element).not_to be_nil

      # Find the Detail child element
      detail_element = error_element.children.detect { |c| c.name == 'Detail' }
      expect(detail_element).not_to be_nil

      # The Detail element should have any_content? set to true
      expect(detail_element.any_content?).to be true
    end
  end

  describe 'to_a representation' do
    it 'includes any_content flag in the element data' do
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => amazon_namespace } }
      elements = builder.build([part])

      error_element = elements.first
      array_representation = error_element.to_a

      # Find the Detail entry in the array representation
      detail_entry = array_representation.detect { |path, _data| path.last == 'Detail' }
      expect(detail_entry).not_to be_nil

      _path, data = detail_entry
      expect(data[:any_content]).to be true
    end
  end
end

RSpec.describe 'xsd:any in ExampleMessage' do
  let(:wsdl_path) { 'spec/fixtures/wsdl/amazon.wsdl' }
  let(:wsdl) { WSDL.new(wsdl_path) }
  let(:schemas) { wsdl.wsdl.schemas }
  let(:amazon_namespace) { 'http://fps.amazonaws.com/doc/2008-09-17/' }

  it 'includes a placeholder for arbitrary content' do
    builder = WSDL::XML::ElementBuilder.new(schemas)

    part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => amazon_namespace } }
    elements = builder.build([part])

    example = WSDL::ExampleMessage.build(elements)

    # The Detail element should have the any content placeholder
    detail = example.dig(:Error, :Detail)
    expect(detail).to include('(any)': 'arbitrary XML content allowed')
  end
end

RSpec.describe 'xsd:any in Message building' do
  describe 'serializing arbitrary content' do
    it 'serializes extra keys as arbitrary XML elements' do
      # Create a mock element with any_content
      element = WSDL::XML::Element.new
      element.name = 'Container'
      element.form = 'unqualified'
      element.any_content = true

      # Add a defined child
      child = WSDL::XML::Element.new
      child.name = 'DefinedChild'
      child.form = 'unqualified'
      child.base_type = 'xsd:string'
      element.children = [child]

      # Create a mock envelope
      envelope = instance_double(WSDL::Envelope)
      allow(envelope).to receive(:register_namespace).and_return(nil)

      message = WSDL::Message.new(envelope, [element])

      # Build with both defined and arbitrary content
      result = message.build({
        Container: {
          DefinedChild: 'defined value',
          ArbitraryElement: 'arbitrary value',
          NestedArbitrary: {
            Inner: 'nested value'
          }
        }
      })

      expect(result).to include('<DefinedChild>defined value</DefinedChild>')
      expect(result).to include('<ArbitraryElement>arbitrary value</ArbitraryElement>')
      expect(result).to include('<NestedArbitrary>')
      expect(result).to include('<Inner>nested value</Inner>')
    end

    it 'handles arrays in arbitrary content' do
      element = WSDL::XML::Element.new
      element.name = 'Container'
      element.form = 'unqualified'
      element.any_content = true
      element.children = []

      envelope = instance_double(WSDL::Envelope)
      allow(envelope).to receive(:register_namespace).and_return(nil)

      message = WSDL::Message.new(envelope, [element])

      result = message.build({
        Container: {
          Items: [
            { Name: 'Item 1' },
            { Name: 'Item 2' }
          ]
        }
      })

      expect(result).to include('<Items>')
      expect(result).to include('<Name>Item 1</Name>')
      expect(result).to include('<Name>Item 2</Name>')
      expect(result.scan('<Items>').length).to eq(2)
    end

    it 'handles nil values in arbitrary content' do
      element = WSDL::XML::Element.new
      element.name = 'Container'
      element.form = 'unqualified'
      element.any_content = true
      element.children = []

      envelope = instance_double(WSDL::Envelope)
      allow(envelope).to receive(:register_namespace).and_return(nil)

      message = WSDL::Message.new(envelope, [element])

      result = message.build({
        Container: {
          EmptyElement: nil
        }
      })

      expect(result).to include('<EmptyElement/>')
    end

    it 'handles attributes in arbitrary content using underscore prefix' do
      element = WSDL::XML::Element.new
      element.name = 'Container'
      element.form = 'unqualified'
      element.any_content = true
      element.children = []

      envelope = instance_double(WSDL::Envelope)
      allow(envelope).to receive(:register_namespace).and_return(nil)

      message = WSDL::Message.new(envelope, [element])

      result = message.build({
        Container: {
          ArbitraryElement: {
            _id: '123',
            _type: 'special',
            Value: 'content'
          }
        }
      })

      expect(result).to include('id="123"')
      expect(result).to include('type="special"')
      expect(result).to include('<Value>content</Value>')
    end
  end
end
