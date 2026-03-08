# frozen_string_literal: true

RSpec.describe WSDL::ParseOptions do
  describe '.default' do
    it 'returns a ParseOptions with sensible defaults' do
      options = described_class.default

      expect(options.sandbox_paths).to be_nil
      expect(options.limits).to eq(WSDL.limits)
      expect(options.strict_schema).to be(true)
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

    it 'falls back to WSDL.limits when limits is nil' do
      options = described_class.default(limits: nil)
      expect(options.limits).to eq(WSDL.limits)
    end

    it 'coerces truthy strict_schema to true' do
      options = described_class.default(strict_schema: 'yes')
      expect(options.strict_schema).to be(true)
    end

    it 'coerces falsy strict_schema to false' do
      options = described_class.default(strict_schema: false)
      expect(options.strict_schema).to be(false)
    end

    it 'coerces nil strict_schema to false' do
      options = described_class.default(strict_schema: nil)
      expect(options.strict_schema).to be(false)
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
      a = described_class.default(strict_schema: true)
      b = described_class.default(strict_schema: false)

      expect(a).not_to eq(b)
    end
  end
end
