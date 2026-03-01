# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Parser::BindingOperation do
  describe '#input_body' do
    it 'returns input body attributes' do
      binding_operation = get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP11Binding', 'getBank')

      expect(binding_operation.input_body).to eq(
        encoding_style: nil,
        namespace: nil,
        use: 'literal'
      )
    end
  end

  describe '#input_headers' do
    it 'returns an empty array when there are no headers' do
      binding_operation = get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP11Binding', 'getBank')

      expect(binding_operation.input_headers).to eq([])
    end
  end

  describe '#output_body' do
    it 'returns output body attributes' do
      binding_operation = get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP11Binding', 'getBank')

      expect(binding_operation.output_body).to eq(
        encoding_style: nil,
        namespace: nil,
        use: 'literal'
      )
    end
  end

  describe '#output_headers' do
    it 'returns an empty array when there are no headers' do
      binding_operation = get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP11Binding', 'getBank')

      expect(binding_operation.output_headers).to eq([])
    end
  end

  def get_binding_operation(fixture_path, binding_name, operation_name)
    client = WSDL::Client.new fixture(fixture_path)
    document = client.parser_result.documents.first
    binding = document.bindings[binding_name]
    binding.operations[operation_name]
  end
end
