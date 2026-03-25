# frozen_string_literal: true

require 'tempfile'

RSpec.describe WSDL::Parser::Input do
  let(:tempfiles) { [] }

  after do
    tempfiles.each(&:close!)
  end

  describe 'header part resolution' do
    it 'skips headers with missing message attribute and records issue' do
      issues = []
      input = build_input(header_missing_message_wsdl, issues:)

      expect(input.header_parts).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first[:error]).to match(/@message is missing/)
    end

    it 'skips headers with missing part attribute and records issue' do
      issues = []
      input = build_input(header_missing_part_wsdl, issues:)

      expect(input.header_parts).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first[:error]).to match(/@part is missing/)
    end

    it 'skips headers with empty message attribute and records issue' do
      issues = []
      input = build_input(header_empty_message_wsdl, issues:)

      expect(input.header_parts).to be_empty
      expect(issues).not_to be_empty
    end

    it 'skips headers with empty part attribute and records issue' do
      issues = []
      input = build_input(header_empty_part_wsdl, issues:)

      expect(input.header_parts).to be_empty
      expect(issues).not_to be_empty
    end

    it 'skips headers referencing missing message parts and records issue' do
      issues = []
      input = build_input(invalid_header_part_wsdl, issues:)

      expect(input.header_parts).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first[:error]).to match(/Unable to find part "missing"/)
    end

    it 'skips output headers referencing missing message parts and records issue' do
      issues = []
      output = build_output(invalid_output_header_part_wsdl, issues:)

      expect(output.header_parts).to be_empty
      expect(issues).not_to be_empty
      expect(issues.first[:error]).to match(/Unable to find part "missing_out"/)
    end
  end

  private

  def build_input(wsdl_xml, issues: nil)
    documents, schemas = import_wsdl(wsdl_xml)
    binding_op, port_type_op = resolve_operations(documents, 'TestService', 'TestPort', 'TestOp')
    WSDL::Parser::Input.new(binding_op, port_type_op,
      documents:, schemas:,
      limits: WSDL.limits, strictness: WSDL.strictness,
      issues:)
  end

  def build_output(wsdl_xml, issues: nil)
    documents, schemas = import_wsdl(wsdl_xml)
    binding_op, port_type_op = resolve_operations(documents, 'TestService', 'TestPort', 'TestOp')
    WSDL::Parser::Output.new(binding_op, port_type_op,
      documents:, schemas:,
      limits: WSDL.limits, strictness: WSDL.strictness,
      issues:)
  end

  def import_wsdl(wsdl_xml)
    wsdl_path = write_wsdl_file(wsdl_xml)
    documents = WSDL::Parser::DocumentCollection.new
    schemas = WSDL::Schema::Collection.new
    source = WSDL::Source.validate_wsdl!(wsdl_path)
    resolver = WSDL::Parser::Resolver.new(http_mock, sandbox_paths: [File.dirname(File.expand_path(wsdl_path))])
    importer = WSDL::Parser::Importer.new(resolver, documents, schemas, WSDL::ParseOptions.default)
    importer.import(source.value)
    [documents, schemas]
  end

  def resolve_operations(documents, service_name, port_name, operation_name)
    port = documents.service_port(service_name, port_name)
    binding = port.fetch_binding(documents)
    port_type = binding.fetch_port_type(documents)
    binding_op = binding.operations.fetch(operation_name)
    port_type_op = port_type.operations.fetch(operation_name)
    [binding_op, port_type_op]
  end

  def write_wsdl_file(wsdl_xml)
    file = Tempfile.new(['parser-input', '.wsdl'])
    file.write(wsdl_xml)
    file.flush
    tempfiles << file
    file.path
  end

  def invalid_header_part_wsdl
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test"
                   name="TestService">
        <types>
          <xsd:schema targetNamespace="urn:test" elementFormDefault="qualified">
            <xsd:element name="TestRequest" type="xsd:string"/>
            <xsd:element name="TestResponse" type="xsd:string"/>
            <xsd:element name="AuthHeader" type="xsd:string"/>
          </xsd:schema>
        </types>
        <message name="TestInput"><part name="parameters" element="tns:TestRequest"/></message>
        <message name="TestOutput"><part name="parameters" element="tns:TestResponse"/></message>
        <message name="AuthMessage"><part name="auth" element="tns:AuthHeader"/></message>
        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="tns:TestInput"/><output message="tns:TestOutput"/>
          </operation>
        </portType>
        <binding name="TestBinding" type="tns:TestPortType">
          <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
          <operation name="TestOp">
            <soap:operation soapAction="urn:test#TestOp"/>
            <input>
              <soap:body use="literal"/>
              <soap:header message="tns:AuthMessage" part="missing" use="literal"/>
            </input>
            <output><soap:body use="literal"/></output>
          </operation>
        </binding>
        <service name="TestService">
          <port name="TestPort" binding="tns:TestBinding">
            <soap:address location="http://example.com/test"/>
          </port>
        </service>
      </definitions>
    XML
  end

  def header_missing_message_wsdl
    invalid_header_part_wsdl.sub(
      '<soap:header message="tns:AuthMessage" part="missing" use="literal"/>',
      '<soap:header part="auth" use="literal"/>'
    )
  end

  def header_missing_part_wsdl
    invalid_header_part_wsdl.sub(
      '<soap:header message="tns:AuthMessage" part="missing" use="literal"/>',
      '<soap:header message="tns:AuthMessage" use="literal"/>'
    )
  end

  def header_empty_message_wsdl
    invalid_header_part_wsdl.sub(
      '<soap:header message="tns:AuthMessage" part="missing" use="literal"/>',
      '<soap:header message="" part="auth" use="literal"/>'
    )
  end

  def header_empty_part_wsdl
    invalid_header_part_wsdl.sub(
      '<soap:header message="tns:AuthMessage" part="missing" use="literal"/>',
      '<soap:header message="tns:AuthMessage" part="" use="literal"/>'
    )
  end

  def invalid_output_header_part_wsdl
    invalid_header_part_wsdl
      .sub(
        '<soap:header message="tns:AuthMessage" part="missing" use="literal"/>',
        ''
      )
      .sub(
        '<output><soap:body use="literal"/></output>',
        '<output><soap:body use="literal"/>' \
        '<soap:header message="tns:AuthMessage" part="missing_out" use="literal"/></output>'
      )
  end
end
