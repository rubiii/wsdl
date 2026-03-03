# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

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

  describe '#documents' do
    it 'returns a sealed document collection after import' do
      expect(parser_result.documents).to be_sealed
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

  describe '#schema_imports' do
    it 'defaults to :best_effort' do
      expect(parser_result.schema_imports).to eq(:best_effort)
    end

    it 'accepts :strict' do
      result = described_class.new(fixture('wsdl/authentication'), http_mock, schema_imports: :strict)
      expect(result.schema_imports).to eq(:strict)
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

  describe 'QName resolution across imported documents' do
    subject(:collision_result) { described_class.new fixture('wsdl/qname_collisions/root'), http_mock }

    it 'keeps same local names from different namespaces as distinct keys' do
      shared_bindings = collision_result.documents.bindings.keys.select { |qname| qname.local == 'SharedBinding' }
      shared_messages = collision_result.documents.messages.keys.select { |qname| qname.local == 'SharedMessageIn' }

      expect(shared_bindings.map(&:namespace)).to contain_exactly('urn:a', 'urn:b')
      expect(shared_messages.map(&:namespace)).to contain_exactly('urn:a', 'urn:b')
    end

    it 'resolves bindings and messages by fully qualified name' do
      a_operation = collision_result.operation('CollisionService', 'APort', 'Ping')
      b_operation = collision_result.operation('CollisionService', 'BPort', 'Ping')

      expect(a_operation.input.body_parts.first.namespace).to eq('urn:a')
      expect(b_operation.input.body_parts.first.namespace).to eq('urn:b')
    end
  end

  describe 'reference errors' do
    it 'raises UnresolvedReferenceError for missing binding references' do
      result = described_class.new(fixture('wsdl/unresolved_references/binding'), http_mock)

      expect {
        result.operations('BadService', 'BadPort')
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:binding)
      }
    end

    it 'raises UnresolvedReferenceError for missing portType references' do
      result = described_class.new(fixture('wsdl/unresolved_references/port_type'), http_mock)

      expect {
        result.operation('BadService', 'BadPort', 'Ping')
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:port_type)
      }
    end

    it 'raises UnresolvedReferenceError for missing message references' do
      result = described_class.new(fixture('wsdl/unresolved_references/message'), http_mock)

      expect {
        result.operation('BadService', 'BadPort', 'Ping').input
      }.to raise_error(WSDL::UnresolvedReferenceError) { |error|
        expect(error.reference_type).to eq(:message)
      }
    end
  end

  describe 'duplicate definition detection' do
    it 'raises DuplicateDefinitionError for duplicate qualified definitions' do
      result = described_class.new(fixture('wsdl/duplicate_definitions/root'), http_mock)

      expect {
        result.documents.messages
      }.to raise_error(WSDL::DuplicateDefinitionError) { |error|
        expect(error.component_type).to eq(:message)
        expect(error.definition_key).to eq('{urn:dup}SharedMessage')
      }
    end
  end

  describe 'schema import failure policy' do
    let(:wsdl_with_missing_schema_import) { fixture('wsdl/juniper') }

    it 'continues on non-security schema import failures in :best_effort mode' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http_mock, schema_imports: :best_effort)
      }.not_to raise_error
    end

    it 'raises non-security schema import failures in :strict mode' do
      expect {
        described_class.new(wsdl_with_missing_schema_import, http_mock, schema_imports: :strict)
      }.to raise_error(WSDL::SchemaImportError) { |error|
        expect(error.cause).to be_a(Errno::ENOENT)
        expect(error.location).to eq('SystemService?xsd=xsd0.xsd')
        expect(error.action).to eq('import')
      }
    end

    it 'always raises PathRestrictionError regardless of policy' do
      malicious_wsdl = fixture('wsdl/malicious/path_traversal')

      expect {
        described_class.new(malicious_wsdl, http_mock, schema_imports: :best_effort)
      }.to raise_error(WSDL::PathRestrictionError)

      expect {
        described_class.new(malicious_wsdl, http_mock, schema_imports: :strict)
      }.to raise_error(WSDL::PathRestrictionError)
    end

    it 'always raises XMLSecurityError regardless of policy' do
      Dir.mktmpdir do |dir|
        wsdl_path = File.join(dir, 'service.wsdl')
        schema_path = File.join(dir, 'imported.xsd')

        File.write(wsdl_path, <<~XML)
          <?xml version="1.0"?>
          <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                       xmlns:xs="http://www.w3.org/2001/XMLSchema"
                       targetNamespace="http://example.com/service"
                       name="TestService">
            <types>
              <xs:schema targetNamespace="http://example.com/service">
                <xs:import namespace="http://example.com/imported" schemaLocation="imported.xsd"/>
              </xs:schema>
            </types>
          </definitions>
        XML

        File.write(schema_path, <<~XML)
          <?xml version="1.0"?>
          <!DOCTYPE schema SYSTEM "http://example.com/schema.dtd">
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://example.com/imported"/>
        XML

        expect {
          described_class.new(wsdl_path, http_mock, schema_imports: :best_effort)
        }.to raise_error(WSDL::XMLSecurityError)

        expect {
          described_class.new(wsdl_path, http_mock, schema_imports: :strict)
        }.to raise_error(WSDL::XMLSecurityError)
      end
    end
  end
end
