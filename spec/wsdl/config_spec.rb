# frozen_string_literal: true

RSpec.describe WSDL::Config do
  subject(:config) { described_class.new }

  describe '.new' do
    it 'has sensible defaults' do
      expect(config.strictness).to eq(WSDL::Strictness.on)
      expect(config.limits).to eq(WSDL::Limits.new)
    end

    it 'accepts custom values' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      config = described_class.new(
        strictness: WSDL::Strictness.off,
        limits: custom_limits
      )

      expect(config.strictness).to eq(WSDL::Strictness.off)
      expect(config.limits).to eq(custom_limits)
    end

    it 'resolves nil limits to Limits defaults' do
      config = described_class.new(limits: nil)
      expect(config.limits).to eq(WSDL::Limits.new)
    end

    it 'is frozen after construction' do
      expect(config).to be_frozen
    end
  end

  describe '#with' do
    it 'returns a new Config with overridden values' do
      modified = config.with(strictness: WSDL::Strictness.off)

      expect(modified.strictness).to eq(WSDL::Strictness.off)
    end

    it 'does not mutate the original' do
      config.with(strictness: WSDL::Strictness.off)

      expect(config.strictness).to eq(WSDL::Strictness.on)
    end

    it 'returns a frozen instance' do
      expect(config.with(strictness: WSDL::Strictness.off)).to be_frozen
    end
  end

  describe '#==' do
    it 'is equal to another Config with the same values' do
      a = described_class.new
      b = described_class.new
      expect(a).to eq(b)
    end

    it 'is not equal when values differ' do
      expect(described_class.new).not_to eq(described_class.new(strictness: false))
    end

    it 'is not equal to non-Config objects' do
      expect(config).not_to eq('not a config')
    end
  end

  describe '#to_h' do
    it 'returns a hash of all settings' do
      hash = config.to_h

      expect(hash).to eq(
        strictness: WSDL::Strictness.on,
        limits: WSDL::Limits.new
      )
    end
  end

  describe '#hash' do
    it 'returns equal hash codes for equal configs' do
      a = described_class.new
      b = described_class.new
      expect(a.hash).to eq(b.hash)
    end
  end

  describe '#inspect' do
    it 'returns a human-readable representation' do
      expect(config.inspect).to start_with('#<WSDL::Config ')
      expect(config.inspect).to include('strictness=')
    end
  end
end
