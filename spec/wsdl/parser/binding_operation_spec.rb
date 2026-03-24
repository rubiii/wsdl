# frozen_string_literal: true

RSpec.describe WSDL::Parser::BindingOperation do
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

  def get_binding_operation(fixture_path, binding_name, operation_name) # rubocop:disable Metrics/AbcSize
    documents = WSDL::Parser::DocumentCollection.new
    schemas = WSDL::Schema::Collection.new
    source = WSDL::Source.validate_wsdl!(fixture(fixture_path))
    resolver = WSDL::Parser::Resolver.new(http_mock,
                                          sandbox_paths: [File.dirname(File.expand_path(fixture(fixture_path)))])
    importer = WSDL::Parser::Importer.new(resolver, documents, schemas, WSDL::ParseOptions.default)
    importer.import(source.value)

    document = documents.first
    _, binding = document.bindings.find { |qname, _| qname.local == binding_name }
    binding.operations.fetch(operation_name)
  end
end
