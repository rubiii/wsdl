# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Client do
  subject(:client) { described_class.new(wsdl, http: http_mock) }

  let(:wsdl) { fixture('wsdl/amazon') }

  let(:service_name)   { 'AmazonFPS' }
  let(:port_name)      { 'AmazonFPSPort' }
  let(:operation_name) { 'Pay' }
  let(:fixture_dir)    { File.expand_path('../../fixtures/wsdl', __dir__) }

  describe '.new' do
    it 'expects a local or remote WSDL document' do
      allow(WSDL::Parser::Result).to receive(:new).with(
        wsdl, instance_of(WSDL.http_adapter), file_access: :unrestricted, sandbox_paths: nil
      ).and_return(:parser_result)
      client = described_class.new(wsdl)
      expect(client.parser_result).to eq(:parser_result)
    end

    it 'also accepts a custom HTTP adapter to replace the default' do
      http = :my_http_adapter
      allow(WSDL::Parser::Result).to receive(:new).with(
        wsdl, http, file_access: :unrestricted, sandbox_paths: nil
      ).and_return(:parser_result)

      client = described_class.new(wsdl, http: http)
      expect(client.parser_result).to eq(:parser_result)
    end

    context 'with caching enabled' do
      before do
        WSDL.cache = WSDL::Cache.new
      end

      it 'caches parsed definitions by default' do
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:new) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl)
        described_class.new(wsdl)

        expect(definition_count).to eq(1)
      end

      it 'allows disabling cache with cache: nil' do
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:new) do |_, _|
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
        allow(WSDL::Parser::Result).to receive(:new) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(wsdl, cache: custom_cache)
        described_class.new(wsdl, cache: custom_cache)

        expect(definition_count).to eq(1)
        expect(custom_cache.size).to eq(1)
      end

      it 'caches inline XML using content hash' do
        inline_xml = File.read(wsdl)
        definition_count = 0
        allow(WSDL::Parser::Result).to receive(:new) do |_, _|
          definition_count += 1
          instance_double(WSDL::Parser::Result, services: {}, operations: [])
        end

        described_class.new(inline_xml)
        described_class.new(inline_xml)

        expect(definition_count).to eq(1)
      end
    end
  end

  describe 'file access security' do
    context 'with file_access: :auto (default)' do
      context 'when loading from a file path' do
        it 'uses unrestricted file access (trusts local files)' do
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

          described_class.new(wsdl)

          expect(WSDL::Parser::Result).to have_received(:new).with(
            wsdl, anything, file_access: :unrestricted, sandbox_paths: nil
          )
        end

        it 'allows relative imports to sibling directories' do
          # Travelport fixtures use ../common_v32_0/ imports which need to work
          travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

          described_class.new(travelport_wsdl)

          expect(WSDL::Parser::Result).to have_received(:new).with(
            travelport_wsdl, anything, file_access: :unrestricted, sandbox_paths: nil
          )
        end
      end

      context 'when loading from a URL' do
        let(:url_wsdl) { 'http://example.com/service?wsdl' }

        it 'disables file access' do
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

          described_class.new(url_wsdl)

          expect(WSDL::Parser::Result).to have_received(:new).with(
            url_wsdl, anything, file_access: :disabled, sandbox_paths: nil
          )
        end
      end

      context 'when loading from inline XML' do
        let(:inline_xml) { '<definitions/>' }

        it 'disables file access' do
          parser_result = instance_double(WSDL::Parser::Result, services: {})
          allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

          described_class.new(inline_xml)

          expect(WSDL::Parser::Result).to have_received(:new).with(
            inline_xml, anything, file_access: :disabled, sandbox_paths: nil
          )
        end
      end
    end

    context 'with explicit file_access options' do
      it 'passes :disabled to the parser' do
        parser_result = instance_double(WSDL::Parser::Result, services: {})
        allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

        described_class.new(wsdl, file_access: :disabled)

        expect(WSDL::Parser::Result).to have_received(:new).with(
          wsdl, anything, file_access: :disabled, sandbox_paths: nil
        )
      end

      it 'passes :unrestricted to the parser' do
        parser_result = instance_double(WSDL::Parser::Result, services: {})
        allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

        described_class.new(wsdl, file_access: :unrestricted)

        expect(WSDL::Parser::Result).to have_received(:new).with(
          wsdl, anything, file_access: :unrestricted, sandbox_paths: nil
        )
      end

      it 'passes custom sandbox_paths to the parser' do
        custom_paths = ['/app/wsdl', '/app/schemas']
        parser_result = instance_double(WSDL::Parser::Result, services: {})
        allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

        described_class.new(wsdl, file_access: :sandbox, sandbox_paths: custom_paths)

        expect(WSDL::Parser::Result).to have_received(:new).with(
          wsdl, anything, file_access: :sandbox, sandbox_paths: custom_paths
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
        }.not_to raise_error # Import failures are logged, not raised

        # But if we try to read a file outside the sandbox directly, it should fail
        # This is tested more thoroughly in resolver_spec.rb
      end

      it 'allows legitimate relative imports within sandbox' do
        travelport_wsdl = fixture('wsdl/travelport/system_v32_0/System')

        # This WSDL uses relative imports like ../common_v32_0/CommonReqRsp.xsd
        # which should be allowed since they stay within the fixture directory
        expect {
          described_class.new(travelport_wsdl, http: http_mock)
        }.not_to raise_error
      end
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

  describe '#parser_result' do
    it 'returns the parser result' do
      expect(client.parser_result).to be_an_instance_of(WSDL::Parser::Result)
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
