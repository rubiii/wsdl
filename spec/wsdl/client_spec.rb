# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe WSDL::Client do
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
        wsdl, instance_of(WSDL.http_adapter), hash_including(sandbox_paths: [wsdl_directory])
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
        wsdl, http, hash_including(sandbox_paths: [wsdl_directory])
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

      it 'allows disabling cache with cache: nil' do
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: nil)
        described_class.new(wsdl, cache: nil)

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

      it 'partitions cache entries by reject_doctype' do
        custom_cache = WSDL::Cache.new
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:parse) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache, reject_doctype: true)
        described_class.new(wsdl, cache: custom_cache, reject_doctype: false)

        expect(definition_count).to eq(2)
        expect(custom_cache.size).to eq(2)
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
          attr_reader :client

          def initialize
            @client = Object.new
          end
        end

        expect {
          described_class.new(wsdl, http: adapter_class.new)
        }.to raise_error(WSDL::InvalidHTTPAdapterError, /must implement #cache_key/)
      end

      it 'raises when explicit HTTP adapter returns empty cache_key' do
        adapter_class = Class.new do
          attr_reader :client

          def initialize
            @client = Object.new
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
          attr_reader :cache_key, :client

          def initialize(cache_key)
            @cache_key = cache_key
            @client = Object.new
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
            wsdl, anything, hash_including(sandbox_paths: [wsdl_directory])
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
            travelport_wsdl, anything, hash_including(sandbox_paths: [travelport_directory])
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
            url_wsdl, anything, hash_including(sandbox_paths: nil)
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
          wsdl, anything, hash_including(sandbox_paths: custom_paths)
        )
      end
    end

    context 'path traversal protection' do
      it 'blocks path traversal attacks in schema imports' do
        malicious_wsdl = fixture('wsdl/malicious/path_traversal')

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

  describe 'strict schema mode' do
    let(:wsdl_with_missing_schema_import) { fixture('wsdl/juniper') }

    it 'defaults to strict mode and raises on schema import failures' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http: http_mock, cache: nil)
      }.to raise_error(WSDL::SchemaImportError)
    end

    it 'tolerates recoverable schema import failures when strict_schema: false' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http: http_mock, cache: nil, strict_schema: false)
      }.not_to raise_error
    end

    it 'passes strict_schema: true to parser' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, strict_schema: true)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, hash_including(strict_schema: true)
      )
    end

    it 'passes strict_schema: false to parser' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, strict_schema: false)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, hash_including(strict_schema: false)
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

    it 'allows WSDL with DOCTYPE when reject_doctype: false' do
      expect {
        described_class.new(wsdl_with_doctype_file.path, http: http_mock, reject_doctype: false)
      }.not_to raise_error
    end

    it 'passes reject_doctype option to parser' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, reject_doctype: false)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, hash_including(reject_doctype: false)
      )
    end

    it 'defaults reject_doctype to true' do
      parser_result = instance_double(WSDL::Parser::Result, services: {})
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, hash_including(reject_doctype: true)
      )
    end
  end

  describe '#pretty_print' do
    it 'defaults to true' do
      expect(client.pretty_print).to be(true)
    end

    it 'can be set to false' do
      client = described_class.new(wsdl, http: http_mock, pretty_print: false)
      expect(client.pretty_print).to be(false)
    end

    it 'passes pretty_print option to operations' do
      client = described_class.new(wsdl, http: http_mock, pretty_print: false)
      operation = client.operation(service_name, port_name, operation_name)

      expect(operation.pretty_print).to be(false)
    end
  end

  describe '#service_name' do
    it 'returns the name of the primary service' do
      expect(client.service_name).to eq('AmazonFPS')
    end
  end

  describe '#strict_schema' do
    it 'defaults to true' do
      expect(client.strict_schema).to be(true)
    end

    it 'returns false when configured with strict_schema: false' do
      relaxed_client = described_class.new(wsdl, http: http_mock, cache: nil, strict_schema: false)
      expect(relaxed_client.strict_schema).to be(false)
    end
  end

  describe '#http' do
    it 'returns the HTTP adapter\'s client to configure' do
      client = described_class.new(wsdl)
      expect(client.http).to be_an_instance_of(HTTPClient)
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

  describe '#limits' do
    it 'uses WSDL.limits by default' do
      expect(client.limits).to eq(WSDL.limits)
    end

    it 'accepts custom limits' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      client_with_limits = described_class.new(wsdl, http: http_mock, limits: custom_limits)

      expect(client_with_limits.limits).to eq(custom_limits)
    end

    it 'passes limits to the parser result' do
      custom_limits = WSDL::Limits.new(max_document_size: 5 * 1024 * 1024)
      parser_result = instance_double(WSDL::Parser::Result, services: {}, limits: custom_limits)
      allow(WSDL::Parser::Result).to receive(:parse).and_return(parser_result)

      described_class.new(wsdl, http: http_mock, limits: custom_limits, cache: nil)

      expect(WSDL::Parser::Result).to have_received(:parse).with(
        wsdl, anything, hash_including(limits: custom_limits)
      )
    end
  end

  describe 'resource limit enforcement' do
    it 'raises ResourceLimitError when document size exceeds limit' do
      tiny_limit = WSDL::Limits.new(max_document_size: 10)

      expect {
        described_class.new(wsdl, http: http_mock, limits: tiny_limit, cache: nil)
      }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
    end

    it 'allows parsing with sufficient limits' do
      generous_limits = WSDL::Limits.new(max_document_size: 10 * 1024 * 1024)

      expect {
        described_class.new(wsdl, http: http_mock, limits: generous_limits, cache: nil)
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
  end
end
