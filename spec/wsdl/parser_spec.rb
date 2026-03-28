# frozen_string_literal: true

require 'logger'

RSpec.describe WSDL::Parser do
  describe '.parse' do
    describe 'QName cache lifecycle' do
      after do
        WSDL::QName.clear_resolve_cache
      end

      it 'clears the QName resolve cache after a successful parse' do
        # Seed the cache before parsing. If the ensure block in
        # Parser.parse is removed, both the seed and any entries added
        # by the build phase survive — failing the assertions below.
        ns = { 'xmlns:tns' => 'http://example.com' }
        WSDL::QName.resolve('tns:Seed', namespaces: ns)

        expect(WSDL::QName.instance_variable_get(:@resolve_cache)).not_to be_empty

        described_class.parse(fixture('wsdl/authentication'), http_mock)

        expect(WSDL::QName.instance_variable_get(:@resolve_cache)).to be_empty
        expect(WSDL::QName.instance_variable_get(:@resolve_dns_cache)).to be_empty
        expect(WSDL::QName.instance_variable_get(:@prefix_cache)).to be_empty
      end

      it 'clears the QName resolve cache even when parse raises' do
        # Seed the cache so we can verify the ensure block fires on
        # the exception path, not just the happy path.
        ns = { 'xmlns:tns' => 'http://example.com' }
        WSDL::QName.resolve('tns:Seed', namespaces: ns)

        expect(WSDL::QName.instance_variable_get(:@resolve_cache)).not_to be_empty

        expect {
          described_class.parse(
            fixture('wsdl/travelport/system_v32_0/System'), http_mock,
            sandbox_paths: [File.expand_path('spec/fixtures/wsdl/travelport')],
            limits: WSDL::Limits.new(max_schemas: 1)
          )
        }.to raise_error(WSDL::ResourceLimitError)

        expect(WSDL::QName.instance_variable_get(:@resolve_cache)).to be_empty
        expect(WSDL::QName.instance_variable_get(:@resolve_dns_cache)).to be_empty
        expect(WSDL::QName.instance_variable_get(:@prefix_cache)).to be_empty
      end
    end

    it 'returns a frozen Definition' do
      definition = described_class.parse(fixture('wsdl/authentication'), http_mock)

      expect(definition).to be_a(WSDL::Definition)
      expect(definition).to be_frozen
    end

    it 'records provenance for resolved documents' do
      definition = described_class.parse(fixture('wsdl/authentication'), http_mock)

      expect(definition.sources).not_to be_empty
      expect(definition.sources.first).to include(status: 'resolved')
      expect(definition.sources.first[:digest]).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'computes a fingerprint from source provenance' do
      definition = described_class.parse(fixture('wsdl/authentication'), http_mock)

      expect(definition.fingerprint).to match(/\Asha256:[a-f0-9]{64}\z/)
    end

    it 'produces stable fingerprints for the same input' do
      d1 = described_class.parse(fixture('wsdl/authentication'), http_mock)
      d2 = described_class.parse(fixture('wsdl/authentication'), http_mock)

      expect(d1.fingerprint).to eq(d2.fingerprint)
    end

    describe 'source validation' do
      it 'rejects inline XML content' do
        expect {
          described_class.parse('<definitions/>', http_mock)
        }.to raise_error(ArgumentError, /Inline XML/)
      end

      it 'rejects file:// URLs' do
        expect {
          described_class.parse('file:///tmp/service.wsdl', http_mock)
        }.to raise_error(ArgumentError, %r{file:// URLs are not supported})
      end

      it 'rejects unsupported URL schemes' do
        expect {
          described_class.parse('ftp://example.com/service.wsdl', http_mock)
        }.to raise_error(ArgumentError, /Unsupported URL scheme/)
      end
    end

    describe 'resource limits' do
      it 'enforces max_schemas limit' do
        travelport = fixture('wsdl/travelport/system_v32_0/System')

        expect {
          described_class.parse(
            travelport, http_mock,
            sandbox_paths: [File.expand_path('spec/fixtures/wsdl/travelport')],
            limits: WSDL::Limits.new(max_schemas: 1)
          )
        }.to raise_error(WSDL::ResourceLimitError, /max_schemas/)
      end
    end

    describe 'schema import failure policy' do
      it 'raises SchemaImportError in strict mode' do
        expect {
          described_class.parse(fixture('wsdl/juniper'), http_mock, strictness: WSDL::Strictness.on)
        }.to raise_error(WSDL::SchemaImportError)
      end

      it 'tolerates failures in lenient mode and records failed sources' do
        definition = described_class.parse(
          fixture('wsdl/juniper'), http_mock,
          strictness: WSDL::Strictness.off
        )

        expect(definition).to be_a(WSDL::Definition)
        expect(definition.sources.any? { |s| s[:status] == 'failed' }).to be(true)
      end
    end

    describe 'duplicate definitions' do
      it 'raises DuplicateDefinitionError when operations reference conflicting messages' do
        # Duplicate messages across imports raise when the Builder resolves them.
        # This fixture has duplicate messages but no services, so Builder never
        # accesses them. The conformance spec (W11-NAME-1) tests the scenario
        # where duplicates are actually encountered during message resolution.
        # Here we verify the DocumentCollection detects duplicates on access.
        result = described_class.import(fixture('parser/duplicate_definitions/root'), http_mock)

        expect { result.documents.messages }.to raise_error(WSDL::DuplicateDefinitionError) { |error|
          expect(error.component_type).to eq(:message)
        }
      end
    end
  end

  describe '.import' do
    it 'returns an ImportResult' do
      result = described_class.import(fixture('wsdl/authentication'), http_mock)

      expect(result).to be_a(WSDL::Parser::ImportResult)
    end

    it 'contains parsed documents' do
      result = described_class.import(fixture('wsdl/authentication'), http_mock)

      expect(result.documents).to be_a(WSDL::Parser::DocumentCollection)
      expect(result.documents.first).to be_a(WSDL::Parser::Document)
    end

    it 'contains parsed schemas' do
      result = described_class.import(fixture('wsdl/authentication'), http_mock)

      expect(result.schemas).to be_a(WSDL::Schema::Collection)
      expect(result.schemas.count).to be_positive
    end

    it 'records provenance for resolved documents' do
      result = described_class.import(fixture('wsdl/authentication'), http_mock)

      expect(result.provenance).not_to be_empty
      expect(result.provenance).to be_frozen
      expect(result.provenance.first).to include(status: 'resolved')
    end

    describe 'lenient schema import mode' do
      let(:result) do
        described_class.import(
          fixture('wsdl/juniper'), http_mock,
          strictness: WSDL::Strictness.off
        )
      end

      it 'collects SchemaImportError instances with error attributes' do
        errors = result.schema_import_errors

        expect(errors).not_to be_empty
        expect(errors).to be_frozen
        expect(errors).to all(be_a(WSDL::SchemaImportError))

        error = errors.first
        expect(error.location).to eq('SystemService?xsd=xsd0.xsd')
        expect(error.action).to eq('import')
        expect(error.message).to include('Failed to resolve XML Schema import')
      end

      it 'logs tolerated schema import errors at warn level' do
        log_output = StringIO.new
        WSDL.logger = Logger.new(log_output)

        described_class.import(
          fixture('wsdl/juniper'), http_mock,
          strictness: WSDL::Strictness.off
        )

        expect(log_output.string).to include('WARN')
        expect(log_output.string).to include('Failed to resolve XML Schema import')
      end

      it 'records failed imports in provenance' do
        failed = result.provenance.select { |p| p[:status] == 'failed' }

        expect(failed).not_to be_empty
        expect(failed.first[:error]).to include('Failed to resolve XML Schema import')
        expect(failed.first[:digest]).to be_nil
      end
    end

    describe 'source validation' do
      it 'rejects inline XML content' do
        expect {
          described_class.import('<definitions/>', http_mock)
        }.to raise_error(ArgumentError, /Inline XML/)
      end
    end
  end
end
