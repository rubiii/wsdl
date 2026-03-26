# frozen_string_literal: true

RSpec.describe WSDL::ParseOptions do
  describe '.default' do
    it 'returns a ParseOptions with sensible defaults' do
      options = described_class.default

      expect(options.sandbox_paths).to be_nil
      expect(options.limits).to eq(WSDL::Limits.new)
      expect(options.strictness).to eq(WSDL::Strictness.new)
    end

    it 'accepts custom sandbox_paths' do
      options = described_class.default(sandbox_paths: ['/tmp'])
      expect(options.sandbox_paths).to eq(['/tmp'])
    end

    it 'accepts custom limits' do
      custom_limits = WSDL::Limits.new(max_schemas: 5)
      options = described_class.default(limits: custom_limits)
      expect(options.limits).to eq(custom_limits)
    end

    it 'falls back to Limits defaults when limits is nil' do
      options = described_class.default(limits: nil)
      expect(options.limits).to eq(WSDL::Limits.new)
    end

    it 'stores Strictness.on correctly' do
      options = described_class.default(strictness: WSDL::Strictness.on)
      expect(options.strictness).to eq(WSDL::Strictness.on)
    end

    it 'stores Strictness.off correctly' do
      options = described_class.default(strictness: WSDL::Strictness.off)
      expect(options.strictness).to eq(WSDL::Strictness.off)
    end

    it 'stores a custom Strictness object correctly' do
      custom = WSDL::Strictness.new(schema_imports: false, request_validation: true)
      options = described_class.default(strictness: custom)
      expect(options.strictness).to eq(custom)
    end
  end

  describe 'immutability' do
    it 'is frozen' do
      options = described_class.default
      expect(options).to be_frozen
    end
  end

  describe 'equality' do
    it 'considers two instances with the same values equal' do
      a = described_class.default
      b = described_class.default

      expect(a).to eq(b)
    end

    it 'considers two instances with different values not equal' do
      a = described_class.default(strictness: WSDL::Strictness.on)
      b = described_class.default(strictness: WSDL::Strictness.off)

      expect(a).not_to eq(b)
    end
  end
end
