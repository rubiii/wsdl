# frozen_string_literal: true

require 'tempfile'

RSpec.describe WSDL::Client do
  subject(:client) { described_class.new(definition, http: http_mock, strictness: WSDL::Strictness.off) }

  let(:wsdl_path) { fixture('wsdl/amazon') }
  let(:definition) { WSDL.parse(wsdl_path) }

  let(:service_name)   { 'AmazonFPS' }
  let(:port_name)      { 'AmazonFPSPort' }
  let(:operation_name) { 'Pay' }
  let(:fixture_dir)    { File.dirname(File.expand_path(wsdl_path)) }

  describe '.new' do
    it 'accepts a Definition' do
      client = described_class.new(definition, http: http_mock)
      expect(client.services).to be_a(Hash)
      expect(client.services).to have_key('AmazonFPS')
    end

    it 'also accepts a custom HTTP client' do
      http = Class.new do
        def get(_url)
          raise 'should not fetch'
        end
      end.new

      client = described_class.new(definition, http:)
      expect(client.services).to have_key('AmazonFPS')
    end

    it 'rejects inline XML content' do
      inline_xml = File.read(wsdl_path)

      expect {
        WSDL.parse(inline_xml)
      }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
    end

    it 'rejects inline XML content with leading whitespace' do
      inline_xml = "   \n\t<definitions/>"

      expect {
        WSDL.parse(inline_xml)
      }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
    end

    it 'rejects file:// URLs' do
      expect {
        WSDL.parse('file:///tmp/service.wsdl')
      }.to raise_error(ArgumentError, %r{file:// URLs are not supported})
    end

    it 'rejects unsupported URL schemes' do
      expect {
        WSDL.parse('ftp://example.com/service.wsdl')
      }.to raise_error(ArgumentError, /Unsupported URL scheme/)
    end
  end

  describe 'file access security' do
    context 'with default sandbox behavior' do
      context 'when loading from a file path' do
        it 'sandboxes to WSDL parent directory' do
          wsdl_directory = File.dirname(File.expand_path(wsdl_path))
          allow(WSDL::Parser).to receive(:parse).and_wrap_original do |method, *args, **kwargs|
            # WSDL.parse passes nil sandbox_paths; Parser.parse resolves from source
            expect(kwargs[:sandbox_paths]).to be_nil
            method.call(*args, **kwargs)
          end

          defn = WSDL.parse(wsdl_path)
          sources = defn.sources.map { |s| s[:location] }

          expect(WSDL::Parser).to have_received(:parse)
          expect(sources).to all(start_with(wsdl_directory))
        end

        it 'blocks imports outside the WSDL parent directory' do
          travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')

          # Default sandbox is the WSDL's parent directory only.
          # Travelport imports ../common_v32_0/ which is outside that sandbox.
          expect {
            WSDL.parse(travelport_wsdl)
          }.to raise_error(WSDL::PathRestrictionError)
        end
      end

      context 'when loading from a URL' do
        it 'disables file access so local file imports are blocked' do
          wsdl_with_file_import = <<~XML
            <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                         xmlns:xs="http://www.w3.org/2001/XMLSchema"
                         xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                         name="Svc" targetNamespace="http://example.com">
              <types>
                <xs:schema targetNamespace="http://example.com">
                  <xs:import schemaLocation="/etc/passwd"/>
                </xs:schema>
              </types>
              <service name="Svc">
                <port name="P" binding="tns:B">
                  <soap:address location="http://example.com/service"/>
                </port>
              </service>
            </definitions>
          XML

          http_mock.fake_request('http://example.com/service?wsdl', status: 200)
          allow(http_mock).to receive(:get).with('http://example.com/service?wsdl').and_return(
            WSDL::HTTP::Response.new(status: 200, body: wsdl_with_file_import)
          )

          expect {
            WSDL.parse('http://example.com/service?wsdl', http: http_mock)
          }.to raise_error(WSDL::PathRestrictionError, /File access is disabled/)
        end
      end

      context 'when loading from inline XML' do
        let(:inline_xml) { '<definitions/>' }

        it 'raises an ArgumentError' do
          expect {
            WSDL.parse(inline_xml)
          }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
        end
      end
    end

    context 'with explicit sandbox_paths option' do
      it 'overrides automatic sandbox with custom paths' do
        travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')
        travelport_root = File.dirname(fixture('wsdl/travelport/manifest'))

        # Default sandbox would block ../common_v32_0/ imports.
        # Custom sandbox_paths that include the parent directory allows them.
        defn = WSDL.parse(travelport_wsdl, sandbox_paths: [travelport_root])
        client = described_class.new(defn)

        expect(client.services).not_to be_empty
      end
    end

    context 'path traversal protection' do
      it 'blocks path traversal attacks in schema imports' do
        malicious_wsdl = fixture('parser/malicious/path_traversal')

        # The WSDL contains schemaLocation="../../../../etc/passwd"
        # which should be blocked by sandbox restrictions
        expect {
          WSDL.parse(malicious_wsdl, http: http_mock)
        }.to raise_error(WSDL::PathRestrictionError)

        # But if we try to read a file outside the sandbox directly, it should fail
        # This is tested more thoroughly in resolver_spec.rb
      end

      it 'requires explicit sandbox paths for sibling relative imports' do
        travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')
        system_dir = File.dirname(File.expand_path(travelport_wsdl))
        common_dir = File.expand_path('../common_v32_0', system_dir)

        expect {
          WSDL.parse(travelport_wsdl, http: http_mock)
        }.to raise_error(WSDL::PathRestrictionError)

        expect {
          WSDL.parse(travelport_wsdl, http: http_mock, sandbox_paths: [system_dir, common_dir])
        }.not_to raise_error
      end
    end
  end

  describe 'unparseable WSDL input' do
    it 'raises WSDL::Error for an empty file' do
      Tempfile.create(['empty', '.wsdl']) do |f|
        expect { WSDL.parse(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for binary garbage' do
      Tempfile.create(['garbage', '.wsdl']) do |f|
        f.write((0..200).map { rand(0..255).chr(Encoding::BINARY) }.join)
        f.close
        expect { WSDL.parse(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for JSON content' do
      Tempfile.create(['json', '.wsdl']) do |f|
        f.write('{"service": "test"}')
        f.close
        expect { WSDL.parse(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for truncated XML' do
      Tempfile.create(['truncated', '.wsdl']) do |f|
        f.write(File.read(fixture('wsdl/blz_service'))[0...10])
        f.close
        expect { WSDL.parse(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end
  end

  describe 'unknown XSD built-in type in strict mode' do
    let(:wsdl_with_unknown_type) do
      <<~WSDL
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://t.com" targetNamespace="http://t.com">
          <types>
            <xsd:schema targetNamespace="http://t.com">
              <xsd:element name="Req" type="xsd:nonExistentType"/>
            </xsd:schema>
          </types>
          <message name="M"><part name="p" element="tns:Req"/></message>
          <portType name="PT">
            <operation name="Op"><input message="tns:M"/><output message="tns:M"/></operation>
          </portType>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="Op">
              <soap:operation soapAction="Op"/>
              <input><soap:body use="literal"/></input>
              <output><soap:body use="literal"/></output>
            </operation>
          </binding>
          <service name="S">
            <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
          </service>
        </definitions>
      WSDL
    end

    it 'records build issue for unknown types' do
      Tempfile.create(['unknown_type', '.wsdl']) do |f|
        f.write(wsdl_with_unknown_type)
        f.close
        defn = WSDL.parse(f.path)
        client = described_class.new(defn)

        expect(client.definition.build_issues).not_to be_empty
        expect(client.definition.build_issues.first[:error]).to match(/Unknown XSD built-in type/)
      end
    end

    it 'raises DefinitionError on verify!' do
      Tempfile.create(['unknown_type', '.wsdl']) do |f|
        f.write(wsdl_with_unknown_type)
        f.close
        definition = WSDL.parse(f.path)

        expect { definition.verify! }.to raise_error(WSDL::DefinitionError, /Unknown XSD built-in type/)
      end
    end

    it 'includes the operation despite unknown types' do
      Tempfile.create(['unknown_type', '.wsdl']) do |f|
        f.write(wsdl_with_unknown_type)
        f.close
        client = described_class.new(WSDL.parse(f.path))

        expect(client.operations('S', 'P')).to include('Op')
      end
    end
  end

  describe 'binding operation with missing input' do
    it 'includes the operation and records a build issue' do
      xml = <<~WSDL
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
      WSDL

      Tempfile.create(['no_input', '.wsdl']) do |f|
        f.write(xml)
        f.close
        client = described_class.new(WSDL.parse(f.path))

        expect(client.operations('S', 'P')).to include('Op')
        expect(client.definition.build_issues).not_to be_empty
        expect(client.definition.build_issues.first[:error]).to match(/missing a required/)
      end
    end
  end

  describe 'binding operation not in portType' do
    it 'includes the operation with a build issue' do
      xml = <<~WSDL
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://t.com" targetNamespace="http://t.com">
          <portType name="PT"/>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="GhostOp">
              <soap:operation soapAction="Op"/>
              <input><soap:body use="literal"/></input>
              <output><soap:body use="literal"/></output>
            </operation>
          </binding>
          <service name="S">
            <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
          </service>
        </definitions>
      WSDL

      Tempfile.create(['ghost_op', '.wsdl']) do |f|
        f.write(xml)
        f.close
        client = described_class.new(WSDL.parse(f.path))

        expect(client.operations('S', 'P')).to include('GhostOp')
        expect(client.definition.build_issues).not_to be_empty
        expect(client.definition.build_issues.first[:error]).to match(/GhostOp.*portType/)
      end
    end
  end

  describe 'one-way operation (no output)' do
    it 'returns empty response contract for one-way operations' do
      xml = <<~WSDL
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://t.com" targetNamespace="http://t.com">
          <message name="M"><part name="p" type="xsd:string"/></message>
          <portType name="PT">
            <operation name="Op"><input message="tns:M"/></operation>
          </portType>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="Op">
              <soap:operation soapAction="Op"/>
              <input><soap:body use="literal"/></input>
            </operation>
          </binding>
          <service name="S">
            <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
          </service>
        </definitions>
      WSDL

      Tempfile.create(['one_way', '.wsdl']) do |f|
        f.write(xml)
        f.close
        client = described_class.new(WSDL.parse(f.path))
        operation = client.operation('S', 'P', 'Op')

        expect(operation.contract.response.body.paths).to eq([])
        expect(operation.contract.response.header.paths).to eq([])
        expect(operation.contract.request.body.paths).not_to be_empty
        expect(operation.output_style).to be_nil
      end
    end
  end

  describe 'operation overloading' do
    let(:overloaded_definition) { WSDL.parse(fixture('parser/operation_overloading')) }

    it 'raises OperationOverloadError in strict mode' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.on)

      expect { client.operation('LookupService', 'LookupPort', 'Lookup') }
        .to raise_error(WSDL::OperationOverloadError, /overloaded.*R2304/)
    end

    it 'resolves overloaded operation by input_name in relaxed mode' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.off)
      op = client.operation('LookupService', 'LookupPort', 'Lookup', input_name: :LookupById)

      expect(op.contract.request.body.paths.first[:path]).to eq(['LookupByIdReq'])
    end

    it 'resolves the other overload by its input_name' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.off)
      op = client.operation('LookupService', 'LookupPort', 'Lookup', input_name: :LookupByName)

      expect(op.contract.request.body.paths.first[:path]).to eq(['LookupByNameReq'])
    end

    it 'raises ArgumentError without input_name for overloaded operation' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.off)

      expect { client.operation('LookupService', 'LookupPort', 'Lookup') }
        .to raise_error(ArgumentError, /overloaded.*Pass input_name.*LookupById.*LookupByName/)
    end

    it 'returns overloaded name once in operations list' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.off)

      expect(client.operations('LookupService', 'LookupPort').count('Lookup')).to eq(1)
    end

    it 'includes overloaded operations with input_name in services hash' do
      client = described_class.new(overloaded_definition, strictness: WSDL::Strictness.off)
      port = client.services['LookupService'][:ports]['LookupPort']

      expect(port[:operations]).to eq([
        { name: 'Lookup', input_name: 'LookupById' },
        { name: 'Lookup', input_name: 'LookupByName' }
      ])
    end

    it 'ignores input_name for non-overloaded operations' do
      client = described_class.new(WSDL.parse(fixture('wsdl/blz_service')))

      expect { client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank, input_name: :anything) }
        .not_to raise_error
    end
  end

  describe 'strict schema mode' do
    let(:wsdl_with_missing_schema_import) { fixture('wsdl/juniper') }

    it 'defaults to strict mode and raises on schema import failures' do
      expect {
        WSDL.parse(wsdl_with_missing_schema_import, http: http_mock)
      }.to raise_error(WSDL::SchemaImportError)
    end

    it 'tolerates recoverable schema import failures when strictness is off' do
      definition = WSDL.parse(
        wsdl_with_missing_schema_import, http: http_mock,
        strictness: WSDL::Strictness.off
      )

      expect(definition).to be_a(WSDL::Definition)
      expect(definition.sources.any? { |s| s[:status] == 'failed' }).to be(true)
    end

    it 'passes Strictness.on to parser' do
      allow(WSDL::Parser).to receive(:parse).and_wrap_original do |method, *args, **kwargs|
        expect(kwargs[:strictness]).to eq(WSDL::Strictness.on)
        method.call(*args, **kwargs)
      end

      WSDL.parse(wsdl_path, http: http_mock, strictness: WSDL::Strictness.on)

      expect(WSDL::Parser).to have_received(:parse)
    end

    it 'passes Strictness.off to parser' do
      allow(WSDL::Parser).to receive(:parse).and_wrap_original do |method, *args, **kwargs|
        expect(kwargs[:strictness]).to eq(WSDL::Strictness.off)
        method.call(*args, **kwargs)
      end

      WSDL.parse(wsdl_path, http: http_mock, strictness: WSDL::Strictness.off)

      expect(WSDL::Parser).to have_received(:parse)
    end
  end

  describe 'DOCTYPE rejection' do
    let(:wsdl_with_doctype) do
      <<~XML
        <?xml version="1.0"?>
        <!DOCTYPE definitions SYSTEM "http://example.com/wsdl.dtd">
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     name="TestService">
          <service name="TestService">
            <port name="TestPort" binding="tns:TestBinding">
              <soap:address location="http://example.com/test"/>
            </port>
          </service>
        </definitions>
      XML
    end
    let(:wsdl_with_doctype_file) do
      file = Tempfile.new(%w[wsdl-doctype .wsdl])
      file.write(wsdl_with_doctype)
      file.flush
      file
    end

    after do
      wsdl_with_doctype_file.close!
    end

    it 'rejects WSDL with DOCTYPE by default' do
      expect {
        WSDL.parse(wsdl_with_doctype_file.path, http: http_mock)
      }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
    end
  end

  describe '#config' do
    it 'returns a Config instance' do
      expect(client.config).to be_a(WSDL::Config)
    end
  end

  describe '#service_name' do
    it 'returns the name of the primary service' do
      expect(client.service_name).to eq('AmazonFPS')
    end
  end

  describe '#config.strictness' do
    it 'defaults to Strictness.on' do
      strict_client = described_class.new(WSDL.parse(fixture('wsdl/authentication'), http: http_mock), http: http_mock)
      expect(strict_client.config.strictness).to eq(WSDL::Strictness.on)
    end

    it 'returns Strictness.off when configured with strictness: Strictness.off' do
      relaxed_client = described_class.new(definition, http: http_mock, strictness: WSDL::Strictness.off)
      expect(relaxed_client.config.strictness).to eq(WSDL::Strictness.off)
    end
  end

  describe '#http' do
    it 'returns the HTTP client\'s config for customization' do
      client = described_class.new(definition)
      expect(client.http).to be_an_instance_of(WSDL::HTTP::Config)
    end
  end

  describe '#services' do
    it 'returns the services and ports defined by the WSDL' do
      expect(client.services).to eq(
        'AmazonFPS' => {
          ports: {
            'AmazonFPSPort' => {
              type: 'http://schemas.xmlsoap.org/wsdl/soap/',
              location: 'https://fps.amazonaws.com',
              operations: [
                { name: 'CancelToken' }, { name: 'Cancel' }, { name: 'FundPrepaid' },
                { name: 'GetAccountActivity' }, { name: 'GetAccountBalance' },
                { name: 'GetDebtBalance' }, { name: 'GetOutstandingDebtBalance' },
                { name: 'GetPrepaidBalance' }, { name: 'GetTokenByCaller' },
                { name: 'CancelSubscriptionAndRefund' }, { name: 'GetTokenUsage' },
                { name: 'GetTokens' }, { name: 'GetTotalPrepaidLiability' },
                { name: 'GetTransaction' }, { name: 'GetTransactionStatus' },
                { name: 'GetPaymentInstruction' }, { name: 'InstallPaymentInstruction' },
                { name: 'Pay' }, { name: 'Refund' }, { name: 'Reserve' }, { name: 'Settle' },
                { name: 'SettleDebt' }, { name: 'WriteOffDebt' },
                { name: 'GetRecipientVerificationStatus' }, { name: 'VerifySignature' }
              ]
            }
          }
        }
      )
    end

    it 'returns a frozen hash' do
      services = client.services
      expect(services).to be_frozen
    end

    it 'deeply freezes nested port and operation structures' do
      services = client.services
      service = services['AmazonFPS']
      port = service[:ports]['AmazonFPSPort']

      expect(service).to be_frozen
      expect(service[:ports]).to be_frozen
      expect(port).to be_frozen
      expect(port[:operations]).to be_frozen
      expect(port[:operations].first).to be_frozen
    end

    it 'returns the same object on repeated calls' do
      expect(client.services).to equal(client.services)
    end

    it 'returns empty operations for ports with unresolvable bindings' do
      wsdl_xml = <<~WSDL
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://example.com" targetNamespace="http://example.com">
          <service name="Svc">
            <port name="P" binding="tns:MissingBinding">
              <soap:address location="http://example.com/service"/>
            </port>
          </service>
        </definitions>
      WSDL

      Tempfile.create(['broken_binding', '.wsdl']) do |f|
        f.write(wsdl_xml)
        f.close
        broken_client = described_class.new(WSDL.parse(f.path, strictness: false))

        port = broken_client.services['Svc'][:ports]['P']
        expect(port[:operations]).to eq([])
      end
    end
  end

  describe '#config.limits' do
    it 'uses Limits defaults when none provided' do
      expect(client.config.limits).to eq(WSDL::Limits.new)
    end

    it 'accepts custom limits' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      client_with_limits = described_class.new(definition, http: http_mock, limits: custom_limits)

      expect(client_with_limits.config.limits).to eq(custom_limits)
    end

    it 'passes limits to the parser' do
      custom_limits = WSDL::Limits.new(max_document_size: 5 * 1024 * 1024)
      allow(WSDL::Parser).to receive(:parse).and_wrap_original do |method, *args, **kwargs|
        expect(kwargs[:limits]).to eq(custom_limits)
        method.call(*args, **kwargs)
      end

      WSDL.parse(wsdl_path, http: http_mock, limits: custom_limits)

      expect(WSDL::Parser).to have_received(:parse)
    end
  end

  describe 'resource limit enforcement' do
    it 'raises ResourceLimitError when document size exceeds limit' do
      tiny_limit = WSDL::Limits.new(max_document_size: 10)

      expect {
        WSDL.parse(wsdl_path, http: http_mock, limits: tiny_limit)
      }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
    end

    it 'allows parsing with sufficient limits' do
      generous_limits = WSDL::Limits.new(max_document_size: 10 * 1024 * 1024)

      expect {
        WSDL.parse(wsdl_path, http: http_mock, limits: generous_limits)
      }.not_to raise_error
    end
  end

  describe '#operations' do
    it 'returns an Array of operations for a service and port' do
      operations = client.operations(service_name, port_name)

      expect(operations.count).to eq(25)
      expect(operations).to include('GetAccountBalance', 'GetTransaction', 'SettleDebt')
    end

    it 'also accepts symbols for the service and port name' do
      operations = client.operations(:AmazonFPS, :AmazonFPSPort)
      expect(operations.count).to eq(25)
    end

    it 'raises if the service could not be found' do
      expect { client.operations(:UnknownService, :UnknownPort) }
        .to raise_error(ArgumentError, /Unknown service "UnknownService"/)
    end

    it 'raises if the port could not be found' do
      expect { client.operations(service_name, :UnknownPort) }
        .to raise_error(ArgumentError, /Unknown service "AmazonFPS" or port "UnknownPort"/)
    end

    context 'with shorthand (no arguments)' do
      it 'auto-resolves the only service and port' do
        operations = client.operations
        expect(operations.count).to eq(25)
        expect(operations).to include('GetAccountBalance', 'GetTransaction', 'SettleDebt')
      end

      it 'raises when the WSDL has multiple services' do
        multi_service_client = described_class.new(
          WSDL.parse(fixture('wsdl/oracle'), http: http_mock, strictness: WSDL::Strictness.off),
          http: http_mock
        )

        expect { multi_service_client.operations }
          .to raise_error(ArgumentError, /Cannot auto-resolve service: expected 1, found \d+/)
      end

      it 'raises when the WSDL has multiple ports' do
        multi_port_client = described_class.new(
          WSDL.parse(fixture('wsdl/temperature'), http: http_mock),
          http: http_mock
        )

        expect { multi_port_client.operations }
          .to raise_error(ArgumentError, /Cannot auto-resolve port.*expected 1, found \d+/)
      end

      it 'raises when called with exactly 1 argument' do
        expect { client.operations(:AmazonFPS) }
          .to raise_error(ArgumentError, /Pass 0 arguments.*or 2 arguments/)
      end
    end
  end

  describe '#operation' do
    it 'returns an Operation by service, port and operation name' do
      operation = client.operation(service_name, port_name, operation_name)
      expect(operation).to be_a(WSDL::Operation)
    end

    it 'also accepts symbols for the service, port and operation name' do
      operation = client.operation(:AmazonFPS, :AmazonFPSPort, :Pay)
      expect(operation).to be_a(WSDL::Operation)
    end

    it 'raises if the service could not be found' do
      expect { client.operation(:UnknownService, :UnknownPort, :UnknownOperation) }
        .to raise_error(ArgumentError, /Unknown service "UnknownService"/)
    end

    it 'raises if the port could not be found' do
      expect { client.operation(service_name, :UnknownPort, :UnknownOperation) }
        .to raise_error(ArgumentError, /Unknown service "AmazonFPS" or port "UnknownPort"/)
    end

    it 'raises if the operation could not be found' do
      expect { client.operation(service_name, port_name, :UnknownOperation) }
        .to raise_error(ArgumentError,
          /Unknown operation "UnknownOperation" for service "AmazonFPS" and port "AmazonFPSPort"/)
    end

    context 'with shorthand (operation name only)' do
      it 'auto-resolves the only service and port' do
        operation = client.operation(:Pay)
        expect(operation).to be_a(WSDL::Operation)
      end

      it 'also accepts a string operation name' do
        operation = client.operation('Pay')
        expect(operation).to be_a(WSDL::Operation)
      end

      it 'raises if the operation does not exist' do
        expect { client.operation(:UnknownOperation) }
          .to raise_error(ArgumentError, /Unknown operation "UnknownOperation"/)
      end

      it 'raises when the WSDL has multiple services' do
        multi_service_client = described_class.new(
          WSDL.parse(fixture('wsdl/oracle'), http: http_mock, strictness: WSDL::Strictness.off),
          http: http_mock
        )

        expect { multi_service_client.operation(:SomeOperation) }
          .to raise_error(ArgumentError, /Cannot auto-resolve service: expected 1, found \d+/)
      end

      it 'raises when the WSDL has multiple ports' do
        multi_port_client = described_class.new(
          WSDL.parse(fixture('wsdl/temperature'), http: http_mock),
          http: http_mock
        )

        expect { multi_port_client.operation(:ConvertTemp) }
          .to raise_error(ArgumentError, /Cannot auto-resolve port.*expected 1, found \d+/)
      end

      it 'raises when called with exactly 2 arguments' do
        expect { client.operation(:AmazonFPS, :AmazonFPSPort) }
          .to raise_error(ArgumentError, /Pass 1 argument.*or 3 arguments/)
      end
    end
  end

  describe 'initialized with a Definition' do
    subject(:client) { described_class.new(definition, http: http_mock) }

    let(:definition) { WSDL.parse(fixture('wsdl/amazon'), http: http_mock) }

    it 'accepts a Definition as the first argument' do
      expect(client).to be_a(described_class)
    end

    it 'returns the Definition via #definition' do
      expect(client.definition).to equal(definition)
    end

    it 'delegates #services to the old API (unchanged)' do
      expect(client.services).to be_a(Hash)
      expect(client.services).to have_key('AmazonFPS')
    end

    it 'delegates #service_name' do
      expect(client.service_name).to eq('AmazonFPS')
    end

    it 'delegates #operations' do
      ops = client.operations(service_name, port_name)
      expect(ops).to include('Pay')
    end

    it 'creates an Operation by service, port and operation name' do
      operation = client.operation(service_name, port_name, operation_name)
      expect(operation).to be_a(WSDL::Operation)
    end

    it 'auto-resolves the only service and port' do
      operation = client.operation(:Pay)
      expect(operation).to be_a(WSDL::Operation)
    end

    it 'creates an Operation with the correct name and endpoint' do
      operation = client.operation(:Pay)

      expect(operation.name).to eq('Pay')
      expect(operation.endpoint).to eq('https://fps.amazonaws.com')
    end

    it 'creates an Operation with correct contract' do
      operation = client.operation(:Pay)
      expect(operation.contract).to be_a(WSDL::Contract::OperationContract)
      expect(operation.contract.style).to eq('document/literal')
    end

    it 'raises for unknown operations' do
      expect {
        client.operation(service_name, port_name, :UnknownOperation)
      }.to raise_error(ArgumentError, /Unknown operation/)
    end

    it 'returns a frozen Definition' do
      defn = WSDL.parse(fixture('wsdl/amazon'), http: http_mock)
      url_client = described_class.new(defn, http: http_mock)
      expect(url_client.definition).to be_a(WSDL::Definition)
      expect(url_client.definition).to be_frozen
    end

    context 'with multiple ports' do
      let(:definition) { WSDL.parse(fixture('wsdl/interhome'), http: http_mock) }

      it 'raises when auto-resolving operations with multiple ports' do
        expect {
          client.operations
        }.to raise_error(ArgumentError, /Cannot auto-resolve port/)
      end

      it 'raises when auto-resolving operation with multiple ports' do
        expect {
          client.operation(:Search)
        }.to raise_error(ArgumentError, /Cannot auto-resolve port/)
      end

      it 'works with explicit service and port' do
        ops = client.operations('WebService', 'WebServiceSoap')
        expect(ops).to include('Search')
      end
    end
  end
end
