# frozen_string_literal: true

RSpec.describe WSDL do
  describe '.http_client' do
    after do
      # reset global state!
      described_class.http_client = nil
    end

    it 'returns the default HTTP client class' do
      expect(described_class.http_client).to eq(WSDL::HTTP::Client)
    end

    it 'can be changed to use a custom client' do
      client_class = Class.new do
        def config
          'http-config'
        end
      end

      described_class.http_client = client_class
      expect(described_class.http_client).to eq(client_class)

      client = WSDL::Client.new(described_class.parse(fixture('wsdl/amazon'), strictness: WSDL::Strictness.off))
      expect(client.http).to eq('http-config')
    end
  end

  describe '.parse' do
    it 'returns a frozen Definition' do
      definition = described_class.parse(fixture('wsdl/authentication'))

      expect(definition).to be_a(WSDL::Definition)
      expect(definition).to be_frozen
    end

    it 'accepts http, strictness, sandbox_paths, and limits options' do
      definition = described_class.parse(
        fixture('wsdl/authentication'),
        http: http_mock,
        strictness: WSDL::Strictness.off,
        limits: WSDL::Limits.new(max_schemas: 200)
      )

      expect(definition).to be_a(WSDL::Definition)
    end

    it 'rejects inline XML content' do
      expect {
        described_class.parse('<definitions/>')
      }.to raise_error(ArgumentError, /Inline XML/)
    end
  end

  describe '.load' do
    it 'restores a Definition from a serialized hash' do
      definition = described_class.parse(fixture('wsdl/authentication'))
      restored = described_class.load(definition.to_h)

      expect(restored).to be_a(WSDL::Definition)
      expect(restored).to be_frozen
      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
    end

    it 'restores a Definition from a JSON round-trip' do
      definition = described_class.parse(fixture('wsdl/authentication'))
      json = definition.to_json
      restored = described_class.load(JSON.parse(json))

      expect(restored.service_name).to eq(definition.service_name)
    end

    it 'raises on schema version mismatch' do
      expect {
        described_class.load({ 'schema_version' => 999 })
      }.to raise_error(ArgumentError, /schema version mismatch/)
    end
  end
end
