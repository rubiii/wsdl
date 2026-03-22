# frozen_string_literal: true

require 'tempfile'

RSpec.describe WSDL::Client do
  subject(:client) { described_class.new(wsdl, http: http_mock) }

  let(:wsdl) { fixture('wsdl/amazon') }

  let(:service_name)   { 'AmazonFPS' }
  let(:port_name)      { 'AmazonFPSPort' }
  let(:operation_name) { 'Pay' }
  let(:fixture_dir)    { File.expand_path('../../fixtures/wsdl', __dir__) }

  describe '.new' do
    it 'expects a local or remote WSDL document' do
      wsdl_directory = File.dirname(File.expand_path(wsdl))
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).with(
        wsdl, instance_of(WSDL.http_adapter), having_attributes(sandbox_paths: [wsdl_directory])
      ).and_return(parser_result)
      client = described_class.new(wsdl)
      expect(client.services).to eq({})
    end

    it 'also accepts a custom HTTP adapter to replace the default' do
      http = Class.new do
        def cache_key
          'my-http-adapter'
        end
      end.new
      wsdl_directory = File.dirname(File.expand_path(wsdl))
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).with(
        wsdl, http, having_attributes(sandbox_paths: [wsdl_directory])
      ).and_return(parser_result)

      client = described_class.new(wsdl, http: http)
      expect(client.services).to eq({})
    end

    context 'with caching enabled' do
      before do
        WSDL.cache = WSDL::Cache.new
      end

      it 'caches parsed definitions by default' do
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl)
        described_class.new(wsdl)

        expect(definition_count).to eq(1)
      end

      it 'allows disabling cache with cache: false' do
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: false)
        described_class.new(wsdl, cache: false)

        expect(definition_count).to eq(2)
      end

      it 'allows using a custom cache instance' do
        custom_cache = WSDL::Cache.new
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache)
        described_class.new(wsdl, cache: custom_cache)

        expect(definition_count).to eq(1)
        expect(custom_cache.size).to eq(1)
      end

      it 'rejects inline XML content' do
        inline_xml = File.read(wsdl)

        expect {
          described_class.new(inline_xml)
        }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
      end

      it 'rejects inline XML content with leading whitespace' do
        inline_xml = "   \n\t<definitions/>"

        expect {
          described_class.new(inline_xml)
        }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
      end

      it 'rejects file:// URLs' do
        expect {
          described_class.new('file:///tmp/service.wsdl')
        }.to raise_error(ArgumentError, %r{file:// URLs are not supported})
      end

      it 'rejects unsupported URL schemes' do
        expect {
          described_class.new('ftp://example.com/service.wsdl')
        }.to raise_error(ArgumentError, /Unsupported URL scheme/)
      end

      it 'partitions cache entries by limits' do
        custom_cache = WSDL::Cache.new
        strict_limits = WSDL::Limits.new(max_document_size: 5 * 1024 * 1024)
        relaxed_limits = WSDL::Limits.new(max_document_size: 10 * 1024 * 1024)
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache, limits: strict_limits)
        described_class.new(wsdl, cache: custom_cache, limits: relaxed_limits)

        expect(definition_count).to eq(2)
        expect(custom_cache.size).to eq(2)
      end

      it 'partitions cache entries by sandbox_paths' do
        custom_cache = WSDL::Cache.new
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache, sandbox_paths: [fixture_dir])
        described_class.new(wsdl, cache: custom_cache, sandbox_paths: [fixture_dir, '/tmp'])

        expect(definition_count).to eq(2)
        expect(custom_cache.size).to eq(2)
      end

      it 'partitions cache entries by strict_schema policy' do
        custom_cache = WSDL::Cache.new
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache, strict_schema: false)
        described_class.new(wsdl, cache: custom_cache, strict_schema: true)

        expect(definition_count).to eq(2)
        expect(custom_cache.size).to eq(2)
      end

      it 'raises when explicit HTTP adapter does not implement cache_key' do
        adapter_class = Class.new do
          attr_reader :config

          def initialize
            @config = Object.new
          end
        end

        expect {
          described_class.new(wsdl, http: adapter_class.new)
        }.to raise_error(WSDL::InvalidHTTPAdapterError, /must implement #cache_key/)
      end

      it 'raises when explicit HTTP adapter returns empty cache_key' do
        adapter_class = Class.new do
          attr_reader :config

          def initialize
            @config = Object.new
          end

          def cache_key
            ''
          end
        end

        expect {
          described_class.new(wsdl, http: adapter_class.new)
        }.to raise_error(WSDL::InvalidHTTPAdapterError, /must return a non-empty #cache_key/)
      end

      it 'shares cache entries across explicit HTTP adapters with the same cache_key' do
        adapter_class = Class.new do
          attr_reader :cache_key, :config

          def initialize(cache_key)
            @cache_key = cache_key
            @config = Object.new
          end
        end

        custom_cache = WSDL::Cache.new
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache, http: adapter_class.new('shared-http'))
        described_class.new(wsdl, cache: custom_cache, http: adapter_class.new('shared-http'))

        expect(definition_count).to eq(1)
        expect(custom_cache.size).to eq(1)
      end
    end
  end

  describe 'file access security' do
    context 'with default sandbox behavior' do
      context 'when loading from a file path' do
        it 'sandboxes to WSDL parent directory' do
          wsdl_directory = File.dirname(File.expand_path(wsdl))
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

          described_class.new(wsdl)

          expect(WSDL::Parser::Result).to have_received(:parse).with(
            wsdl, anything, having_attributes(sandbox_paths: [wsdl_directory])
          )
        end

        it 'sandboxes to the WSDL parent directory for relative imports' do
          # Travelport fixtures use ../common_v32_0/ imports
          # These will be blocked since sandbox is the WSDL's parent directory only
          travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')
          travelport_directory = File.dirname(File.expand_path(travelport_wsdl))
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

          described_class.new(travelport_wsdl)

          expect(WSDL::Parser::Result).to have_received(:parse).with(
            travelport_wsdl, anything, having_attributes(sandbox_paths: [travelport_directory])
          )
        end
      end

      context 'when loading from a URL' do
        let(:url_wsdl) { 'http://example.com/service?wsdl' }

        it 'disables file access' do
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

          described_class.new(url_wsdl)

          expect(WSDL::Parser::Result).to have_received(:parse).with(
            url_wsdl, anything, having_attributes(sandbox_paths: nil)
          )
        end
      end

      context 'when loading from inline XML' do
        let(:inline_xml) { '<definitions/>' }

        it 'raises an ArgumentError' do
          expect {
            described_class.new(inline_xml)
          }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
        end
      end
    end

    context 'with explicit sandbox_paths option' do
      it 'overrides automatic sandbox with custom paths' do
        custom_paths = ['/app/wsdl', '/app/schemas']
        parser_result = instance_double(WSDL::Parser::Result, services: {})
        allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

        described_class.new(wsdl, sandbox_paths: custom_paths)

        expect(WSDL::Parser::Result).to have_received(:parse).with(
          wsdl, anything, having_attributes(sandbox_paths: custom_paths)
        )
      end
    end

    context 'path traversal protection' do
      it 'blocks path traversal attacks in schema imports' do
        malicious_wsdl = fixture('parser/malicious/path_traversal')

        # The WSDL contains schemaLocation="../../../../etc/passwd"
        # which should be blocked by sandbox restrictions
        expect {
          described_class.new(malicious_wsdl, http: http_mock)
        }.to raise_error(WSDL::PathRestrictionError)

        # But if we try to read a file outside the sandbox directly, it should fail
        # This is tested more thoroughly in resolver_spec.rb
      end

      it 'requires explicit sandbox paths for sibling relative imports' do
        travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')
        system_dir = File.dirname(File.expand_path(travelport_wsdl))
        common_dir = File.expand_path('../common_v32_0', system_dir)

        expect {
          described_class.new(travelport_wsdl, http: http_mock)
        }.to raise_error(WSDL::PathRestrictionError)

        expect {
          described_class.new(travelport_wsdl, http: http_mock, sandbox_paths: [system_dir, common_dir])
        }.not_to raise_error
      end
    end
  end

  describe 'unparseable WSDL input' do
    it 'raises WSDL::Error for an empty file' do
      Tempfile.create(['empty', '.wsdl']) do |f|
        expect { described_class.new(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for binary garbage' do
      Tempfile.create(['garbage', '.wsdl']) do |f|
        f.write((0..200).map { rand(0..255).chr(Encoding::BINARY) }.join)
        f.close
        expect { described_class.new(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for JSON content' do
      Tempfile.create(['json', '.wsdl']) do |f|
        f.write('{"service": "test"}')
        f.close
        expect { described_class.new(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end

    it 'raises WSDL::Error for truncated XML' do
      Tempfile.create(['truncated', '.wsdl']) do |f|
        f.write(File.read(fixture('wsdl/blz_service'))[0...10])
        f.close
        expect { described_class.new(f.path) }.to raise_error(WSDL::Error, /could not be parsed/)
      end
    end
  end

  describe 'binding operation with missing input' do
    it 'raises WSDL::Error when binding operation has no input element' do
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
        client = described_class.new(f.path)
        expect {
          client.operation('S', 'P', 'Op')
        }.to raise_error(WSDL::UnresolvedReferenceError, /missing a required <input>/)
      end
    end
  end

  describe 'binding operation not in portType' do
    it 'raises UnresolvedReferenceError when binding operation has no matching portType operation' do
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
        client = described_class.new(f.path)

        # The operation is listed (it's in the binding)
        expect(client.operations('S', 'P')).to include('GhostOp')

        # But resolving it fails because the portType doesn't define it
        expect { client.operation('S', 'P', 'GhostOp') }
          .to raise_error(WSDL::UnresolvedReferenceError, /GhostOp.*portType/)
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
        client = described_class.new(f.path)
        operation = client.operation('S', 'P', 'Op')

        expect(operation.contract.response.body.elements).to eq([])
        expect(operation.contract.response.header.elements).to eq([])
        expect(operation.contract.request.body.elements).not_to be_empty
        expect(operation.output_style).to be_nil
      end
    end
  end

  describe 'strict schema mode' do
    let(:wsdl_with_missing_schema_import) { fixture('wsdl/juniper') }

    it 'defaults to strict mode and raises on schema import failures' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http: http_mock, cache: false)
      }.to raise_error(WSDL::SchemaImportError)
    end

    it 'tolerates recoverable schema import failures when strict_schema: false' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http: http_mock, cache: false, strict_schema: false)
      }.not_to raise_error
    end

    it 'passes strict_schema: true to parser' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, strict_schema: true)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, having_attributes(strict_schema: true)
      )
    end

    it 'passes strict_schema: false to parser' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, strict_schema: false)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, having_attributes(strict_schema: false)
      )
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
        described_class.new(wsdl_with_doctype_file.path, http: http_mock)
      }.to raise_error(WSDL::XMLSecurityError, /DOCTYPE declarations are not allowed/)
    end
  end

  describe '#config' do
    it 'returns a Config instance' do
      expect(client.config).to be_a(WSDL::Config)
    end

    it 'defaults format_xml to true' do
      expect(client.config.format_xml).to be(true)
    end

    it 'accepts format_xml: false' do
      client = described_class.new(wsdl, http: http_mock, format_xml: false)
      expect(client.config.format_xml).to be(false)
    end

    it 'passes format_xml option to operations' do
      client = described_class.new(wsdl, http: http_mock, format_xml: false)
      operation = client.operation(service_name, port_name, operation_name)

      expect(operation.format_xml).to be(false)
    end
  end

  describe '#service_name' do
    it 'returns the name of the primary service' do
      expect(client.service_name).to eq('AmazonFPS')
    end
  end

  describe '#config.strict_schema' do
    it 'defaults to true' do
      expect(client.config.strict_schema).to be(true)
    end

    it 'returns false when configured with strict_schema: false' do
      relaxed_client = described_class.new(wsdl, http: http_mock, cache: false, strict_schema: false)
      expect(relaxed_client.config.strict_schema).to be(false)
    end
  end

  describe '#http' do
    it 'returns the HTTP adapter\'s config for customization' do
      client = described_class.new(wsdl)
      expect(client.http).to be_an_instance_of(WSDL::HTTPAdapter::Config)
    end
  end

  describe '#services' do
    it 'returns the services and ports defined by the WSDL' do
      expect(client.services).to eq(
        'AmazonFPS' => {
          ports: {
            'AmazonFPSPort' => {
              type: 'http://schemas.xmlsoap.org/wsdl/soap/',
              location: 'https://fps.amazonaws.com'
            }
          }
        }
      )
    end
  end

  describe '#config.limits' do
    it 'uses WSDL.limits by default' do
      expect(client.config.limits).to eq(WSDL.limits)
    end

    it 'accepts custom limits' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      client_with_limits = described_class.new(wsdl, http: http_mock, limits: custom_limits)

      expect(client_with_limits.config.limits).to eq(custom_limits)
    end

    it 'passes limits to the parser result' do
      custom_limits = WSDL::Limits.new(max_document_size: 5 * 1024 * 1024)
      parser_result = instance_double(WSDL::Parser::Result, services: {}, limits: custom_limits)
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, limits: custom_limits, cache: false)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, having_attributes(limits: custom_limits)
      )
    end
  end

  describe 'resource limit enforcement' do
    it 'raises ResourceLimitError when document size exceeds limit' do
      tiny_limit = WSDL::Limits.new(max_document_size: 10)

      expect {
        described_class.new(wsdl, http: http_mock, limits: tiny_limit, cache: false)
      }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
    end

    it 'allows parsing with sufficient limits' do
      generous_limits = WSDL::Limits.new(max_document_size: 10 * 1024 * 1024)

      expect {
        described_class.new(wsdl, http: http_mock, limits: generous_limits, cache: false)
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
        multi_service_client = described_class.new(fixture('wsdl/oracle'), http: http_mock, strict_schema: false)

        expect { multi_service_client.operations }
          .to raise_error(ArgumentError, /Cannot auto-resolve service: expected 1, found \d+/)
      end

      it 'raises when the WSDL has multiple ports' do
        multi_port_client = described_class.new(fixture('wsdl/temperature'), http: http_mock)

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
        multi_service_client = described_class.new(fixture('wsdl/oracle'), http: http_mock, strict_schema: false)

        expect { multi_service_client.operation(:SomeOperation) }
          .to raise_error(ArgumentError, /Cannot auto-resolve service: expected 1, found \d+/)
      end

      it 'raises when the WSDL has multiple ports' do
        multi_port_client = described_class.new(fixture('wsdl/temperature'), http: http_mock)

        expect { multi_port_client.operation(:ConvertTemp) }
          .to raise_error(ArgumentError, /Cannot auto-resolve port.*expected 1, found \d+/)
      end

      it 'raises when called with exactly 2 arguments' do
        expect { client.operation(:AmazonFPS, :AmazonFPSPort) }
          .to raise_error(ArgumentError, /Pass 1 argument.*or 3 arguments/)
      end
    end
  end
end
