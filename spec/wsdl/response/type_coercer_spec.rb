# frozen_string_literal: true

RSpec.describe WSDL::Response::TypeCoercer do
  describe '.coerce' do
    it 'leaves unknown types untouched' do
      expect(described_class.coerce('abc', 'xsd:unknownType')).to eq('abc')
    end

    it 'keeps common string types as strings' do
      value = described_class.coerce('value', 'xsd:string')

      expect(value).to eq('value')
      expect(value).to be_a(String)
    end

    it 'converts integer types' do
      value = described_class.coerce('42', 'xsd:int')

      expect(value).to eq(42)
      expect(value).to be_a(Integer)
    end

    it 'converts decimal types' do
      value = described_class.coerce('99.99', 'xsd:decimal')

      expect(value).to eq(BigDecimal('99.99'))
      expect(value).to be_a(BigDecimal)
    end

    it 'converts float types' do
      value = described_class.coerce('3.14', 'xsd:double')

      expect(value).to be_within(0.0001).of(3.14)
      expect(value).to be_a(Float)
    end

    it 'converts boolean lexical values' do
      expect(described_class.coerce('true', 'xsd:boolean')).to be(true)
      expect(described_class.coerce('1', 'xsd:boolean')).to be(true)
      expect(described_class.coerce('false', 'xsd:boolean')).to be(false)
      expect(described_class.coerce('0', 'xsd:boolean')).to be(false)
    end

    it 'returns original value for invalid booleans' do
      expect(described_class.coerce('yes', 'xsd:boolean')).to eq('yes')
    end

    it 'converts ISO dates' do
      value = described_class.coerce('2024-01-15', 'xsd:date')

      expect(value).to eq(Date.new(2024, 1, 15))
      expect(value).to be_a(Date)
    end

    it 'returns original value for invalid dates' do
      expect(described_class.coerce('01/15/2024', 'xsd:date')).to eq('01/15/2024')
    end

    it 'converts ISO dateTime values' do
      value = described_class.coerce('2024-01-15T10:30:00Z', 'xsd:dateTime')

      expect(value).to be_a(Time)
      expect(value.utc.iso8601).to eq('2024-01-15T10:30:00Z')
    end

    it 'keeps dateTime values without explicit timezone as strings' do
      expect(described_class.coerce('2024-01-15T10:30:00', 'xsd:dateTime')).to eq('2024-01-15T10:30:00')
    end

    it 'returns original value for invalid dateTime values' do
      expect(described_class.coerce('2024-01-15 10:30:00', 'xsd:dateTime')).to eq('2024-01-15 10:30:00')
    end

    it 'converts xsd:time values' do
      value = described_class.coerce('10:30:00Z', 'xsd:time')

      expect(value).to be_a(Time)
      expect(value.utc.iso8601).to eq('1970-01-01T10:30:00Z')
    end

    it 'keeps xsd:time values without explicit timezone as strings' do
      expect(described_class.coerce('10:30:00', 'xsd:time')).to eq('10:30:00')
    end

    it 'returns original value for invalid xsd:time values' do
      expect(described_class.coerce('10:30', 'xsd:time')).to eq('10:30')
    end

    it 'decodes base64 values' do
      expect(described_class.coerce('SGVsbG8=', 'xsd:base64Binary')).to eq('Hello')
    end

    it 'decodes hex binary values' do
      expect(described_class.coerce('48656C6C6F', 'xsd:hexBinary')).to eq('Hello')
    end

    it 'returns odd-length hex strings unchanged' do
      expect(described_class.coerce('ABC', 'xsd:hexBinary')).to eq('ABC')
    end

    it 'returns non-hex strings unchanged' do
      expect(described_class.coerce('GHIJKL', 'xsd:hexBinary')).to eq('GHIJKL')
    end

    it 'returns empty values unchanged' do
      expect(described_class.coerce('', 'xsd:int')).to eq('')
      expect(described_class.coerce(nil, 'xsd:int')).to be_nil
    end

    it 'returns original value for invalid decimal values' do
      expect(described_class.coerce('not-a-number', 'xsd:decimal')).to eq('not-a-number')
    end

    it 'returns original value for invalid float values' do
      expect(described_class.coerce('not-a-float', 'xsd:float')).to eq('not-a-float')
    end

    it 'returns original value for unparseable dateTime with timezone' do
      expect(described_class.coerce('9999-99-99T99:99:99Z', 'xsd:dateTime')).to eq('9999-99-99T99:99:99Z')
    end

    it 'returns original value for unparseable xsd:time with timezone' do
      expect(described_class.coerce('99:99:99Z', 'xsd:time')).to eq('99:99:99Z')
    end
  end
end
