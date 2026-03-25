# frozen_string_literal: true

RSpec.describe WSDL::Parser do
  describe '.parse' do
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
            WSDL::ParseOptions.new(
              sandbox_paths: [File.expand_path('spec/fixtures/wsdl/travelport')],
              limits: WSDL::Limits.new(max_schemas: 1),
              strictness: WSDL::Strictness.new
            )
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
        documents = WSDL::Parser::DocumentCollection.new
        schemas = WSDL::Schema::Collection.new
        source = WSDL::Resolver::Source.validate_wsdl!(fixture('parser/duplicate_definitions/root'))
        sandbox = [File.dirname(File.expand_path(fixture('parser/duplicate_definitions/root')))]
        loader = WSDL::Resolver::Loader.new(http_mock, sandbox_paths: sandbox)
        importer = WSDL::Resolver::Importer.new(loader, documents, schemas, WSDL::ParseOptions.default)
        importer.import(source.value)

        expect { documents.messages }.to raise_error(WSDL::DuplicateDefinitionError) { |error|
          expect(error.component_type).to eq(:message)
        }
      end
    end
  end
end
