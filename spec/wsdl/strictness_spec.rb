# frozen_string_literal: true

RSpec.describe WSDL::Strictness do
  describe '.new' do
    it 'defaults all settings to true' do
      strictness = described_class.new

      expect(strictness.schema_imports).to be(true)
      expect(strictness.schema_references).to be(true)
      expect(strictness.operation_overloading).to be(true)
      expect(strictness.request_validation).to be(true)
    end

    it 'accepts individual settings' do
      strictness = described_class.new(schema_imports: false, request_validation: false)

      expect(strictness.schema_imports).to be(false)
      expect(strictness.schema_references).to be(true)
      expect(strictness.operation_overloading).to be(true)
      expect(strictness.request_validation).to be(false)
    end

    it 'coerces truthy values to true' do
      strictness = described_class.new(schema_imports: 'yes')

      expect(strictness.schema_imports).to be(true)
    end

    it 'coerces falsy values to false' do
      strictness = described_class.new(schema_imports: nil)

      expect(strictness.schema_imports).to be(false)
    end

    it 'freezes the instance' do
      expect(described_class.new).to be_frozen
    end
  end

  describe '.resolve' do
    it 'returns a Strictness as-is' do
      original = described_class.on
      expect(described_class.resolve(original)).to equal(original)
    end

    it 'coerces a Hash into a Strictness' do
      result = described_class.resolve(schema_imports: false)
      expect(result.schema_imports).to be(false)
      expect(result.schema_references).to be(true)
    end

    it 'coerces true to Strictness.on' do
      expect(described_class.resolve(true)).to eq(described_class.on)
    end

    it 'coerces false to Strictness.off' do
      expect(described_class.resolve(false)).to eq(described_class.off)
    end

    it 'returns nil for nil' do
      expect(described_class.resolve(nil)).to be_nil
    end

    it 'raises ArgumentError for unsupported types' do
      expect { described_class.resolve(42) }.to raise_error(ArgumentError, /Cannot coerce/)
    end
  end

  describe '.on' do
    it 'returns a strictness with all settings enabled' do
      expect(described_class.on).to eq(described_class.new)
    end
  end

  describe '.off' do
    it 'returns a strictness with all settings disabled' do
      strictness = described_class.off

      expect(strictness.schema_imports).to be(false)
      expect(strictness.schema_references).to be(false)
      expect(strictness.operation_overloading).to be(false)
      expect(strictness.request_validation).to be(false)
    end
  end

  describe '#with' do
    it 'returns a new instance with overridden settings' do
      original = described_class.on
      modified = original.with(schema_imports: false)

      expect(modified.schema_imports).to be(false)
      expect(modified.schema_references).to be(true)
    end

    it 'does not modify the original' do
      original = described_class.on
      original.with(schema_imports: false)

      expect(original.schema_imports).to be(true)
    end

    it 'preserves unspecified settings' do
      original = described_class.new(schema_imports: false, request_validation: false)
      modified = original.with(schema_imports: true)

      expect(modified.schema_imports).to be(true)
      expect(modified.request_validation).to be(false)
    end
  end

  describe '#to_h' do
    it 'returns a hash of all settings' do
      expect(described_class.on.to_h).to eq(
        schema_imports: true,
        schema_references: true,
        operation_overloading: true,
        request_validation: true
      )
    end
  end

  describe '#==' do
    it 'is equal when all settings match' do
      expect(described_class.on).to eq(described_class.new)
    end

    it 'is not equal when any setting differs' do
      expect(described_class.on).not_to eq(described_class.off)
    end
  end

  describe '#hash' do
    it 'is equal for equal instances' do
      expect(described_class.on.hash).to eq(described_class.new.hash)
    end

    it 'differs for different instances' do
      expect(described_class.on.hash).not_to eq(described_class.off.hash)
    end
  end

  describe '#inspect' do
    it 'returns a readable representation' do
      expect(described_class.on.inspect).to include('schema_imports: true')
      expect(described_class.off.inspect).to include('request_validation: false')
    end
  end
end
