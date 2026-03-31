# frozen_string_literal: true

RSpec.describe WSDL do
  describe '.parse' do
    it 'returns a frozen Definition' do
      definition = described_class.parse(fixture('wsdl/authentication'), http: http_mock)

      expect(definition).to be_a(WSDL::Definition)
      expect(definition).to be_frozen
    end

    it 'provides services discovery' do
      definition = described_class.parse(fixture('wsdl/authentication'), http: http_mock)

      expect(definition.services).to eq([
        {
          name: 'AuthenticationWebServiceImplService',
          ports: ['AuthenticationWebServiceImplPort']
        }
      ])
    end

    it 'provides operation introspection' do
      definition = described_class.parse(fixture('wsdl/authentication'), http: http_mock)
      elements = definition.input('authenticate')

      expect(elements).to be_an(Array)
      expect(elements).not_to be_empty
    end

    it 'collects provenance with digests' do
      definition = described_class.parse(fixture('wsdl/authentication'), http: http_mock)

      expect(definition.sources).not_to be_empty
      expect(definition.sources.first['digest']).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'computes a fingerprint' do
      definition = described_class.parse(fixture('wsdl/authentication'), http: http_mock)

      expect(definition.fingerprint).to match(/\Asha256:[a-f0-9]{64}\z/)
    end

    it 'accepts strictness option' do
      definition = described_class.parse(fixture('wsdl/juniper'), http: http_mock,
        strictness: { schema_imports: false })

      expect(definition).to be_a(WSDL::Definition)
      expect(definition.sources.any? { |s| s['status'] == 'failed' }).to be true
    end

    it 'accepts limits option' do
      expect {
        described_class.parse(fixture('wsdl/edialog'), http: http_mock, limits: { max_schemas: 5 })
      }.to raise_error(WSDL::ResourceLimitError)
    end

    it 'parses every standard fixture' do
      %w[authentication temperature blz_service bronto interhome].each do |name|
        definition = described_class.parse(fixture("wsdl/#{name}"), http: http_mock)

        expect(definition.services).not_to be_empty, "#{name}: expected services"
        expect(definition.fingerprint).to match(/\Asha256:/), "#{name}: expected fingerprint"
      end
    end
  end

  describe '.load' do
    let(:definition) { described_class.parse(fixture('wsdl/authentication'), http: http_mock) }

    it 'restores a Definition from a hash' do
      restored = described_class.load(definition.to_h)

      expect(restored).to be_a(WSDL::Definition)
      expect(restored).to be_frozen
    end

    it 'round-trips through to_h' do
      restored = described_class.load(definition.to_h)

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
      expect(restored.to_h).to eq(definition.to_h)
    end

    it 'round-trips through JSON' do
      json = definition.to_json
      restored = described_class.load(JSON.parse(json))

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
    end

    it 'raises on schema version mismatch' do
      hash = definition.to_h.dup
      hash['schema_version'] = 999

      expect {
        described_class.load(hash)
      }.to raise_error(WSDL::SchemaVersionError, /schema version mismatch/)
    end

    it 'round-trips every standard fixture' do
      %w[authentication temperature blz_service bronto].each do |name|
        original = described_class.parse(fixture("wsdl/#{name}"), http: http_mock)
        restored = described_class.load(JSON.parse(original.to_json))

        expect(restored.to_h).to eq(original.to_h), "#{name}: round-trip mismatch"
      end
    end
  end

  describe '.dump' do
    let(:definition) { described_class.parse(fixture('wsdl/authentication'), http: http_mock) }

    it 'returns a serializable hash' do
      hash = described_class.dump(definition)

      expect(hash).to be_a(Hash)
      expect(hash.keys).to all(be_a(String))
    end

    it 'produces the same hash as Definition#to_h' do
      expect(described_class.dump(definition)).to eq(definition.to_h)
    end

    it 'is the inverse of .load' do
      restored = described_class.load(described_class.dump(definition))

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
      expect(restored.to_h).to eq(definition.to_h)
    end

    it 'round-trips through JSON with .load' do
      json = JSON.generate(described_class.dump(definition))
      restored = described_class.load(JSON.parse(json))

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
    end

    it 'round-trips every standard fixture' do
      %w[authentication temperature blz_service bronto].each do |name|
        original = described_class.parse(fixture("wsdl/#{name}"), http: http_mock)
        restored = described_class.load(described_class.dump(original))

        expect(restored.to_h).to eq(original.to_h), "#{name}: dump/load round-trip mismatch"
      end
    end
  end
end
