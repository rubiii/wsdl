# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Parser::Result do
  subject(:parser_result) { described_class.new fixture('wsdl/authentication'), http_mock }

  let(:operation_name) { 'authenticate' }
  let(:service_name)   { 'AuthenticationWebServiceImplService' }
  let(:port_name)      { 'AuthenticationWebServiceImplPort' }

  describe '#service_name' do
    it 'returns the name of the service' do
      expect(parser_result.service_name).to eq('AuthenticationWebServiceImplService')
    end
  end

  describe '#services' do
    it 'returns a map of services and ports' do
      expect(parser_result.services).to eq(
        'AuthenticationWebServiceImplService' => {
          ports: {
            'AuthenticationWebServiceImplPort' => {
              type: 'http://schemas.xmlsoap.org/wsdl/soap/',
              location: 'http://example.com/validation/1.0/AuthenticationService'
            }
          }
        }
      )
    end
  end

  describe '#operations' do
    it 'returns an Array of operation names' do
      operations = parser_result.operations(service_name, port_name)
      expect(operations).to eq([operation_name])
    end
  end

  describe '#operation' do
    it 'returns a single operation by name' do
      operation = parser_result.operation(service_name, port_name, operation_name)
      expect(operation).to be_a(WSDL::Parser::OperationInfo)
    end
  end

  describe '#limits' do
    it 'uses WSDL.limits by default' do
      expect(parser_result.limits).to eq(WSDL.limits)
    end

    it 'accepts custom limits' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      result = described_class.new(fixture('wsdl/authentication'), http_mock, limits: custom_limits)

      expect(result.limits).to eq(custom_limits)
    end
  end

  describe 'resource limit enforcement' do
    context 'with max_schemas limit' do
      it 'raises ResourceLimitError when schema count exceeds limit' do
        # The edialog fixture has 21 schema definitions
        edialog_wsdl = fixture('wsdl/edialog')
        very_low_limit = WSDL::Limits.new(max_schemas: 5)

        expect {
          described_class.new(edialog_wsdl, http_mock, limits: very_low_limit)
        }.to raise_error(WSDL::ResourceLimitError, /Schema count.*exceeds limit/)
      end

      it 'includes limit details in the error' do
        edialog_wsdl = fixture('wsdl/edialog')
        very_low_limit = WSDL::Limits.new(max_schemas: 5)

        expect {
          described_class.new(edialog_wsdl, http_mock, limits: very_low_limit)
        }.to raise_error(WSDL::ResourceLimitError) { |e|
          expect(e.limit_name).to eq(:max_schemas)
          expect(e.limit_value).to eq(5)
        }
      end

      it 'allows parsing when schema count is within limit' do
        # Default limits should be sufficient for normal WSDLs
        expect {
          described_class.new(fixture('wsdl/authentication'), http_mock)
        }.not_to raise_error
      end

      it 'allows unlimited schemas when limit is nil' do
        unlimited = WSDL::Limits.new(max_schemas: nil)
        edialog_wsdl = fixture('wsdl/edialog')

        expect {
          described_class.new(edialog_wsdl, http_mock, limits: unlimited)
        }.not_to raise_error
      end
    end
  end
end
