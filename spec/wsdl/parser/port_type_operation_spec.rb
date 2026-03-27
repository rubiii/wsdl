# frozen_string_literal: true

RSpec.describe WSDL::Parser::PortTypeOperation do
  describe '#name' do
    it 'returns the operation name attribute' do
      node = build_operation_node('GetPrice')
      operation = described_class.new(node)

      expect(operation.name).to eq('GetPrice')
    end
  end

  describe '#input' do
    it 'returns a MessageReference for the input element' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest')
      operation = described_class.new(node)

      expect(operation.input).to be_a(WSDL::Parser::MessageReference)
      expect(operation.input.message).to eq('tns:GetPriceRequest')
      expect(operation.input.message_name.namespace).to eq('urn:test')
      expect(operation.input.message_name.local).to eq('GetPriceRequest')
    end

    it 'returns nil when there is no input element' do
      node = build_operation_node('Notify', input_message: nil, output_message: 'tns:Event')
      operation = described_class.new(node)

      expect(operation.input).to be_nil
    end

    it 'memoizes the result' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest')
      operation = described_class.new(node)

      first_call = operation.input
      second_call = operation.input
      expect(first_call).to be(second_call)
    end

    it 'memoizes nil when there is no input element' do
      node = build_operation_node('Notify', input_message: nil, output_message: 'tns:Event')
      operation = described_class.new(node)
      allow(operation).to receive(:parse_node).and_call_original

      operation.input
      operation.input

      expect(operation).not_to have_received(:parse_node)
    end
  end

  describe '#output' do
    it 'returns a MessageReference for the output element' do
      node = build_operation_node('GetPrice',
        output_message: 'tns:GetPriceResponse')
      operation = described_class.new(node)

      expect(operation.output).to be_a(WSDL::Parser::MessageReference)
      expect(operation.output.message).to eq('tns:GetPriceResponse')
      expect(operation.output.message_name.namespace).to eq('urn:test')
      expect(operation.output.message_name.local).to eq('GetPriceResponse')
    end

    it 'returns nil when there is no output element' do
      node = build_operation_node('Submit',
        input_message: 'tns:SubmitRequest', output_message: nil)
      operation = described_class.new(node)

      expect(operation.output).to be_nil
    end

    it 'memoizes the result' do
      node = build_operation_node('GetPrice',
        output_message: 'tns:GetPriceResponse')
      operation = described_class.new(node)

      first_call = operation.output
      second_call = operation.output
      expect(first_call).to be(second_call)
    end

    it 'memoizes nil when there is no output element' do
      node = build_operation_node('Submit',
        input_message: 'tns:SubmitRequest', output_message: nil)
      operation = described_class.new(node)
      allow(operation).to receive(:parse_node).and_call_original

      operation.output
      operation.output

      expect(operation).not_to have_received(:parse_node)
    end
  end

  describe '#input_name' do
    it 'returns the name attribute of the input element' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest', input_name: 'GetPriceIn')
      operation = described_class.new(node)

      expect(operation.input_name).to eq('GetPriceIn')
    end

    it 'returns nil when input has no name attribute' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest')
      operation = described_class.new(node)

      expect(operation.input_name).to be_nil
    end

    it 'returns nil when there is no input element' do
      node = build_operation_node('Notify',
        input_message: nil, output_message: 'tns:Event')
      operation = described_class.new(node)

      expect(operation.input_name).to be_nil
    end
  end

  describe 'namespace resolution' do
    it 'resolves QName prefixes using in-scope namespace declarations' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest',
        output_message: 'tns:GetPriceResponse')
      operation = described_class.new(node)

      expect(operation.input.message_name.namespace).to eq('urn:test')
      expect(operation.output.message_name.namespace).to eq('urn:test')
    end

    it 'uses pre-resolved namespaces when provided' do
      node = build_operation_node('GetPrice',
        input_message: 'custom:Request',
        output_message: 'custom:Response')
      namespaces = { 'xmlns:custom' => 'urn:custom-ns' }.freeze
      operation = described_class.new(node, namespaces:)

      expect(operation.input.message_name.namespace).to eq('urn:custom-ns')
      expect(operation.output.message_name.namespace).to eq('urn:custom-ns')
    end

    it 'falls back to the operation node namespaces when none are provided' do
      node = build_operation_node('GetPrice',
        input_message: 'tns:GetPriceRequest')
      operation = described_class.new(node)

      ns = operation.send(:namespaces)
      expect(ns).to include('xmlns:tns' => 'urn:test')
      expect(ns).to be_frozen
    end
  end

  private

  def build_operation_node(name, input_message: 'tns:TestInput',
                           output_message: 'tns:TestOutput', input_name: nil)
    children = []

    if input_message
      name_attr = input_name ? " name=\"#{input_name}\"" : ''
      children << "<input#{name_attr} message=\"#{input_message}\"/>"
    end

    children << "<output message=\"#{output_message}\"/>" if output_message

    xml = <<~XML
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test">
        <portType name="TestPortType">
          <operation name="#{name}">
            #{children.join("\n            ")}
          </operation>
        </portType>
      </definitions>
    XML

    doc = Nokogiri::XML(xml)
    doc.at_xpath(
      '//wsdl:operation',
      'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'
    )
  end
end
