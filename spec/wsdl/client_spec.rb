# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Client do
  subject(:client) { described_class.new(wsdl, http: http_mock) }

  let(:wsdl) { fixture('wsdl/amazon') }

  let(:service_name)   { 'AmazonFPS' }
  let(:port_name)      { 'AmazonFPSPort' }
  let(:operation_name) { 'Pay' }

  describe '.new' do
    it 'expects a local or remote WSDL document' do
      allow(WSDL::Parser::Result).to receive(:new).with(wsdl,
                                                        instance_of(WSDL.http_adapter)).and_return(:parser_result)
      client = described_class.new(wsdl)
      expect(client.parser_result).to eq(:parser_result)
    end

    it 'also accepts a custom HTTP adapter to replace the default' do
      http = :my_http_adapter
      allow(WSDL::Parser::Result).to receive(:new).with(wsdl, http).and_return(:parser_result)

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
