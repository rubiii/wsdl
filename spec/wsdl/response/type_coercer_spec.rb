# frozen_string_literal: true

require 'logger'

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

    it 'converts XSD float special values' do
      expect(described_class.coerce('INF', 'xsd:float')).to eq(Float::INFINITY)
      expect(described_class.coerce('-INF', 'xsd:float')).to eq(-Float::INFINITY)
      expect(described_class.coerce('NaN', 'xsd:float')).to be_nan
    end

    it 'converts XSD double special values' do
      expect(described_class.coerce('INF', 'xsd:double')).to eq(Float::INFINITY)
      expect(described_class.coerce('-INF', 'xsd:double')).to eq(-Float::INFINITY)
      expect(described_class.coerce('NaN', 'xsd:double')).to be_nan
    end

    it 'converts integers with leading zeros as base-10' do
      expect(described_class.coerce('010', 'xsd:int')).to eq(10)
      expect(described_class.coerce('099', 'xsd:int')).to eq(99)
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

    # Gregorian date fragment types — stay as strings per spec
    # (timezone suffixes would be lost if converted to Integer)

    it 'keeps gYear as string' do
      expect(described_class.coerce('2024', 'xsd:gYear')).to eq('2024')
    end

    it 'keeps gYear with timezone as string' do
      expect(described_class.coerce('2024+05:30', 'xsd:gYear')).to eq('2024+05:30')
    end

    it 'keeps gYearMonth as string' do
      expect(described_class.coerce('2024-03', 'xsd:gYearMonth')).to eq('2024-03')
    end

    it 'keeps gMonthDay as string' do
      expect(described_class.coerce('--03-22', 'xsd:gMonthDay')).to eq('--03-22')
    end

    it 'keeps gDay as string' do
      expect(described_class.coerce('---22', 'xsd:gDay')).to eq('---22')
    end

    it 'keeps gMonth as string' do
      expect(described_class.coerce('--03', 'xsd:gMonth')).to eq('--03')
    end

    it 'keeps duration as string' do
      expect(described_class.coerce('P1Y2M3DT4H5M6S', 'xsd:duration')).to eq('P1Y2M3DT4H5M6S')
    end

    it 'keeps NOTATION as string' do
      expect(described_class.coerce('myNotation', 'xsd:NOTATION')).to eq('myNotation')
    end

    it 'keeps anyType as string' do
      expect(described_class.coerce('anything', 'xsd:anyType')).to eq('anything')
    end

    it 'keeps anySimpleType as string' do
      expect(described_class.coerce('anything', 'xsd:anySimpleType')).to eq('anything')
    end

    # List types — split on whitespace into Array<String>

    it 'splits IDREFS into an array' do
      expect(described_class.coerce('id1 id2 id3', 'xsd:IDREFS')).to eq(%w[id1 id2 id3])
    end

    it 'splits ENTITIES into an array' do
      expect(described_class.coerce('ent1 ent2', 'xsd:ENTITIES')).to eq(%w[ent1 ent2])
    end

    it 'splits NMTOKENS into an array' do
      expect(described_class.coerce('tok1 tok2 tok3', 'xsd:NMTOKENS')).to eq(%w[tok1 tok2 tok3])
    end

    it 'returns single-element array for single list value' do
      expect(described_class.coerce('single', 'xsd:IDREFS')).to eq(%w[single])
    end
  end

  describe 'coercion fallback logging' do
    let(:log_output) { StringIO.new }

    before do
      WSDL.logger = Logger.new(log_output, level: Logger::DEBUG)
    end

    it 'logs when integer coercion fails' do
      described_class.coerce('abc', 'xsd:int')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"abc"')
      expect(log_output.string).to include('to integer')
    end

    it 'logs when decimal coercion fails' do
      described_class.coerce('not-a-number', 'xsd:decimal')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"not-a-number"')
      expect(log_output.string).to include('to decimal')
    end

    it 'logs when float coercion fails' do
      described_class.coerce('not-a-float', 'xsd:float')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"not-a-float"')
      expect(log_output.string).to include('to float')
    end

    it 'logs when boolean coercion fails' do
      described_class.coerce('yes', 'xsd:boolean')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"yes"')
      expect(log_output.string).to include('to boolean')
    end

    it 'logs when date coercion fails' do
      described_class.coerce('01/15/2024', 'xsd:date')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"01/15/2024"')
      expect(log_output.string).to include('to date')
    end

    it 'logs when dateTime coercion fails' do
      described_class.coerce('9999-99-99T99:99:99Z', 'xsd:dateTime')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"9999-99-99T99:99:99Z"')
      expect(log_output.string).to include('to dateTime')
    end

    it 'logs when time coercion fails' do
      described_class.coerce('99:99:99Z', 'xsd:time')

      expect(log_output.string).to include('Type coercion failed')
      expect(log_output.string).to include('"99:99:99Z"')
      expect(log_output.string).to include('to time')
    end

    it 'does not log when coercion succeeds' do
      described_class.coerce('42', 'xsd:int')
      described_class.coerce('010', 'xsd:int')
      described_class.coerce('99.99', 'xsd:decimal')
      described_class.coerce('3.14', 'xsd:double')
      described_class.coerce('INF', 'xsd:float')
      described_class.coerce('-INF', 'xsd:double')
      described_class.coerce('NaN', 'xsd:float')
      described_class.coerce('true', 'xsd:boolean')
      described_class.coerce('2024-01-15', 'xsd:date')
      described_class.coerce('2024-01-15T10:30:00Z', 'xsd:dateTime')
      described_class.coerce('10:30:00Z', 'xsd:time')

      expect(log_output.string).not_to include('Type coercion failed')
    end

    it 'does not log for dateTime without explicit timezone' do
      described_class.coerce('2024-01-15T10:30:00', 'xsd:dateTime')
      described_class.coerce('10:30:00', 'xsd:time')

      expect(log_output.string).not_to include('Type coercion failed')
    end
  end
end
