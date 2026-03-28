# frozen_string_literal: true

RSpec.describe WSDL::Parser::OperationInfo do
  after do
    tempfiles.each(&:close!)
  end

  describe 'document/literal operation (authentication)' do
    subject(:op_info) do
      resolve_op_info('wsdl/authentication',
        'AuthenticationWebServiceImplService', 'AuthenticationWebServiceImplPort', 'authenticate')
    end

    describe '#input?' do
      it 'returns true when the binding defines an input element' do
        expect(op_info.input?).to be true
      end
    end

    describe '#rpc_input_namespace' do
      it 'returns nil for document/literal operations' do
        expect(op_info.rpc_input_namespace).to be_nil
      end
    end

    describe '#rpc_output_namespace' do
      it 'returns nil for document/literal operations' do
        expect(op_info.rpc_output_namespace).to be_nil
      end
    end
  end

  describe 'rpc/literal operation with namespace (rpc_literal op1)' do
    subject(:op_info) do
      resolve_op_info('wsdl/rpc_literal', 'SampleService', 'Sample', 'op1')
    end

    describe '#rpc_input_namespace' do
      it 'returns the input body namespace' do
        expect(op_info.rpc_input_namespace).to eq('http://apiNamespace.com')
      end
    end

    describe '#rpc_output_namespace' do
      it 'returns the output body namespace' do
        expect(op_info.rpc_output_namespace).to eq('http://apiNamespace.com')
      end
    end
  end

  describe 'rpc/literal operation without namespace (rpc_literal op3)' do
    subject(:op_info) do
      resolve_op_info('wsdl/rpc_literal', 'SampleService', 'Sample', 'op3')
    end

    describe '#rpc_input_namespace' do
      it 'returns nil when input body has no namespace' do
        expect(op_info.rpc_input_namespace).to be_nil
      end
    end

    describe '#rpc_output_namespace' do
      it 'returns nil when output body has no namespace' do
        expect(op_info.rpc_output_namespace).to be_nil
      end
    end
  end

  describe 'binding operation without input element' do
    subject(:op_info) do
      resolve_op_info_from_wsdl(<<~XML, 'S', 'P', 'Op')
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://t.com" targetNamespace="http://t.com">
          <portType name="PT"><operation name="Op"/></portType>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="Op"><soap:operation soapAction="Op"/></operation>
          </binding>
          <service name="S">
            <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
          </service>
        </definitions>
      XML
    end

    describe '#input?' do
      it 'returns false when the binding has no input element' do
        expect(op_info.input?).to be false
      end
    end
  end

  private

  def resolve_op_info(fixture_path, service, port, operation)
    result = WSDL::Parser.import(fixture(fixture_path), http_mock)
    build_op_info(result.documents, result.schemas, service, port, operation)
  end

  def resolve_op_info_from_wsdl(wsdl_xml, service, port, operation)
    file = Tempfile.new(['op-info-spec', '.wsdl'])
    file.write(wsdl_xml)
    file.flush
    tempfiles << file

    result = WSDL::Parser.import(file.path, http_mock)
    build_op_info(result.documents, result.schemas, service, port, operation)
  end

  def build_op_info(documents, schemas, service, port, operation)
    port_obj = documents.service_port(service, port)
    binding = port_obj.fetch_binding(documents)
    port_type = binding.fetch_port_type(documents)

    binding_op = binding.operations.fetch(operation)
    port_type_op = port_type.operations.fetch(operation)

    WSDL::Parser::OperationInfo.new(
      operation, binding_op, port_type_op,
      documents:, schemas:, limits: WSDL::Limits.new
    )
  end

  def tempfiles
    @tempfiles ||= []
  end
end
