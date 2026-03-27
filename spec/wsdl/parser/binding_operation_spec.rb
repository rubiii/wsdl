# frozen_string_literal: true

RSpec.describe WSDL::Parser::BindingOperation do
  describe 'SOAP 1.1 document/literal (blz_service)' do
    subject(:operation) { get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP11Binding', 'getBank') }

    describe '#name' do
      it 'returns the operation name' do
        expect(operation.name).to eq('getBank')
      end
    end

    describe '#soap_namespace' do
      it 'returns the SOAP 1.1 namespace' do
        expect(operation.soap_namespace).to eq(WSDL::NS::WSDL_SOAP_1_1)
      end
    end

    describe '#soap_action' do
      it 'returns the soapAction value' do
        expect(operation.soap_action).to eq('')
      end
    end

    describe '#style' do
      it 'returns the operation style' do
        expect(operation.style).to eq('document')
      end
    end

    describe '#input?' do
      it 'returns true when the operation has an input element' do
        expect(operation.input?).to be true
      end
    end

    describe '#input_name' do
      it 'returns nil when the input element has no name attribute' do
        expect(operation.input_name).to be_nil
      end
    end

    describe '#output_name' do
      it 'returns nil when the output element has no name attribute' do
        expect(operation.output_name).to be_nil
      end
    end

    describe '#input_body' do
      it 'returns input body attributes' do
        expect(operation.input_body).to eq(
          encoding_style: nil,
          namespace: nil,
          use: 'literal'
        )
      end
    end

    describe '#input_headers' do
      it 'returns an empty array when there are no headers' do
        expect(operation.input_headers).to eq([])
      end
    end

    describe '#output_body' do
      it 'returns output body attributes' do
        expect(operation.output_body).to eq(
          encoding_style: nil,
          namespace: nil,
          use: 'literal'
        )
      end
    end

    describe '#output_headers' do
      it 'returns an empty array when there are no headers' do
        expect(operation.output_headers).to eq([])
      end
    end
  end

  describe 'SOAP 1.2 document/literal (blz_service)' do
    subject(:operation) { get_binding_operation('wsdl/blz_service', 'BLZServiceSOAP12Binding', 'getBank') }

    describe '#soap_namespace' do
      it 'returns the SOAP 1.2 namespace' do
        expect(operation.soap_namespace).to eq(WSDL::NS::WSDL_SOAP_1_2)
      end
    end

    describe '#soap_action' do
      it 'returns the soapAction value' do
        expect(operation.soap_action).to eq('')
      end
    end

    describe '#style' do
      it 'returns the operation style' do
        expect(operation.style).to eq('document')
      end
    end

    describe '#input_body' do
      it 'returns input body attributes' do
        expect(operation.input_body).to eq(
          encoding_style: nil,
          namespace: nil,
          use: 'literal'
        )
      end
    end
  end

  describe 'RPC/encoded with input/output names (data_exchange)' do
    subject(:operation) { get_binding_operation('wsdl/data_exchange', 'DataExchangeSoapBinding', 'submit') }

    describe '#style' do
      it 'returns the rpc style' do
        expect(operation.style).to eq('rpc')
      end
    end

    describe '#input_name' do
      it 'returns the input name attribute' do
        expect(operation.input_name).to eq('submitRequest')
      end
    end

    describe '#output_name' do
      it 'returns the output name attribute' do
        expect(operation.output_name).to eq('submitResponse')
      end
    end

    describe '#input_body' do
      it 'returns input body attributes with encoding style and namespace' do
        expect(operation.input_body).to eq(
          encoding_style: 'http://schemas.xmlsoap.org/soap/encoding/',
          namespace: 'http://dataexchange.yfu.org',
          use: 'encoded'
        )
      end
    end
  end

  describe 'document/literal with headers (bronto)' do
    subject(:operation) do
      get_binding_operation('wsdl/bronto', 'BrontoSoapApiImplServiceSoapBinding', 'readLogins')
    end

    describe '#input_name' do
      it 'returns the input name attribute' do
        expect(operation.input_name).to eq('readLogins')
      end
    end

    describe '#input_headers' do
      it 'returns header references' do
        headers = operation.input_headers

        expect(headers.size).to eq(1)
        expect(headers.first).to be_a(WSDL::Parser::HeaderReference)
        expect(headers.first.part).to eq('sessionHeader')
        expect(headers.first.use).to eq('literal')
      end
    end

    describe '#input_body' do
      it 'returns input body attributes' do
        expect(operation.input_body).to eq(
          encoding_style: nil,
          namespace: nil,
          use: 'literal'
        )
      end
    end

    describe '#output_name' do
      it 'returns the output name attribute' do
        expect(operation.output_name).to eq('readLoginsResponse')
      end
    end

    describe '#output_body' do
      it 'returns output body attributes' do
        expect(operation.output_body).to eq(
          encoding_style: nil,
          namespace: nil,
          use: 'literal'
        )
      end
    end

    describe '#output_headers' do
      it 'returns an empty array when the output has no headers' do
        expect(operation.output_headers).to eq([])
      end
    end
  end

  describe 'operation without input (notification-style)' do
    subject(:operation) do
      xml = Nokogiri::XML(<<~XML)
        <wsdl:operation name="notify"
            xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/">
          <soap:operation soapAction="urn:notify" style="document"/>
          <wsdl:output>
            <soap:body use="literal"/>
          </wsdl:output>
        </wsdl:operation>
      XML

      described_class.new(xml.root)
    end

    describe '#input?' do
      it 'returns false when the operation has no input element' do
        expect(operation.input?).to be false
      end
    end

    describe '#input_name' do
      it 'returns nil' do
        expect(operation.input_name).to be_nil
      end
    end

    describe '#input_body' do
      it 'returns an empty hash' do
        expect(operation.input_body).to eq({})
      end
    end

    describe '#input_headers' do
      it 'returns an empty array' do
        expect(operation.input_headers).to eq([])
      end
    end
  end

  def get_binding_operation(fixture_path, binding_name, operation_name) # rubocop:disable Metrics/AbcSize
    documents = WSDL::Parser::DocumentCollection.new
    schemas = WSDL::Schema::Collection.new
    source = WSDL::Resolver::Source.validate_wsdl!(fixture(fixture_path))
    loader = WSDL::Resolver::Loader.new(http_mock,
      sandbox_paths: [File.dirname(File.expand_path(fixture(fixture_path)))])
    importer = WSDL::Resolver::Importer.new(loader, documents, schemas, WSDL::ParseOptions.default)
    importer.import(source.value)

    document = documents.first
    _, binding = document.bindings.find { |qname, _| qname.local == binding_name }
    binding.operations.fetch(operation_name)
  end
end
