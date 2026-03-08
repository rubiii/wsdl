# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Config do
  subject(:config) { described_class.new }

  describe '.new' do
    it 'has sensible defaults' do
      expect(config.format_xml).to be(true)
      expect(config.strict_schema).to be(true)
      expect(config.sandbox_paths).to be_nil
      expect(config.limits).to eq(WSDL.limits)
    end

    it 'accepts custom values' do
      custom_limits = WSDL::Limits.new(max_schemas: 200)
      config = described_class.new(
        format_xml: false,
        strict_schema: false,
        sandbox_paths: ['/tmp'],
        limits: custom_limits
      )

      expect(config.format_xml).to be(false)
      expect(config.strict_schema).to be(false)
      expect(config.sandbox_paths).to eq(['/tmp'])
      expect(config.limits).to eq(custom_limits)
    end

    it 'coerces strict_schema to boolean' do
      config = described_class.new(strict_schema: nil)
      expect(config.strict_schema).to be(false)
    end

    it 'resolves nil limits to WSDL.limits' do
      config = described_class.new(limits: nil)
      expect(config.limits).to eq(WSDL.limits)
    end

    it 'is frozen after construction' do
      expect(config).to be_frozen
    end
  end

  describe '#with' do
    it 'returns a new Config with overridden values' do
      modified = config.with(format_xml: false, strict_schema: false)

      expect(modified.format_xml).to be(false)
      expect(modified.strict_schema).to be(false)
    end

    it 'does not mutate the original' do
      config.with(format_xml: false)

      expect(config.format_xml).to be(true)
    end

    it 'returns a frozen instance' do
      expect(config.with(format_xml: false)).to be_frozen
    end
  end

  describe '#==' do
    it 'is equal to another Config with the same values' do
      a = described_class.new
      b = described_class.new
      expect(a).to eq(b)
    end

    it 'is not equal when values differ' do
      expect(described_class.new(format_xml: true)).not_to eq(described_class.new(format_xml: false))
    end

    it 'is not equal to non-Config objects' do
      expect(config).not_to eq('not a config')
    end
  end

  describe '#to_h' do
    it 'returns a hash of all settings' do
      hash = config.to_h

      expect(hash).to eq(
        format_xml: true,
        strict_schema: true,
        sandbox_paths: nil,
        limits: WSDL.limits
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
      expect(config.inspect).to include('format_xml=true')
    end
  end
end
