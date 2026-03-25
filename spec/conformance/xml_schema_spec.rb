# frozen_string_literal: true

# Tests verifying conformance to normative requirements from the
# W3C XML Schema Part 1: Structures (https://www.w3.org/TR/xmlschema-1/) and
# Part 2: Datatypes (https://www.w3.org/TR/xmlschema-2/).
#
# Scoped to XSD features this library actually uses: type coercion,
# cardinality, form qualification, type inheritance, and nillability.

RSpec.describe 'XML Schema conformance' do
  # --------------------------------------------------------------------------
  # Type Coercion (Part 2: Datatypes)
  # --------------------------------------------------------------------------

  describe 'Type Coercion' do
    def coerce(value, type)
      WSDL::Response::TypeCoercer.coerce(value, type)
    end

    def parse_with_schema(xml, schema)
      WSDL::Response::Parser.parse(xml, schema:)
    end

    describe 'boolean' do
      # https://www.w3.org/TR/xmlschema-2/#boolean
      it 'XSD-BOOL-1: accepts "true" as true' do
        expect(coerce('true', 'xsd:boolean')).to be true
      end

      it 'XSD-BOOL-2: accepts "false" as false' do
        expect(coerce('false', 'xsd:boolean')).to be false
      end

      it 'XSD-BOOL-3: accepts "1" as true' do
        expect(coerce('1', 'xsd:boolean')).to be true
      end

      it 'XSD-BOOL-4: accepts "0" as false' do
        expect(coerce('0', 'xsd:boolean')).to be false
      end

      it 'XSD-BOOL-5: rejects non-canonical forms like "TRUE" or "yes"' do
        expect(coerce('TRUE', 'xsd:boolean')).to eq('TRUE')
        expect(coerce('yes', 'xsd:boolean')).to eq('yes')
      end
    end

    describe 'integer types' do
      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-1: xsd:integer coerces to Integer' do
        expect(coerce('42', 'xsd:integer')).to eq(42)
        expect(coerce('42', 'xsd:integer')).to be_a(Integer)
      end

      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-2: xsd:int coerces to Integer' do
        expect(coerce('-2147483648', 'xsd:int')).to eq(-2_147_483_648)
      end

      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-3: xsd:long coerces to Integer' do
        expect(coerce('9223372036854775807', 'xsd:long')).to eq(9_223_372_036_854_775_807)
      end

      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-4: xsd:short and xsd:byte coerce to Integer' do
        expect(coerce('32767', 'xsd:short')).to eq(32_767)
        expect(coerce('127', 'xsd:byte')).to eq(127)
      end

      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-5: unsigned types coerce to Integer' do
        expect(coerce('255', 'xsd:unsignedByte')).to eq(255)
        expect(coerce('65535', 'xsd:unsignedShort')).to eq(65_535)
        expect(coerce('4294967295', 'xsd:unsignedInt')).to eq(4_294_967_295)
        expect(coerce('18446744073709551615', 'xsd:unsignedLong')).to eq(18_446_744_073_709_551_615)
      end

      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-INT-6: negative integer variants coerce correctly' do
        expect(coerce('-1', 'xsd:negativeInteger')).to eq(-1)
        expect(coerce('0', 'xsd:nonPositiveInteger')).to eq(0)
        expect(coerce('0', 'xsd:nonNegativeInteger')).to eq(0)
        expect(coerce('1', 'xsd:positiveInteger')).to eq(1)
      end

      it 'XSD-INT-7: non-numeric values fall back to string' do
        expect(coerce('abc', 'xsd:int')).to eq('abc')
      end
    end

    describe 'decimal' do
      # https://www.w3.org/TR/xmlschema-2/#decimal
      it 'XSD-DEC-1: xsd:decimal coerces to BigDecimal' do
        result = coerce('99.99', 'xsd:decimal')
        expect(result).to eq(BigDecimal('99.99'))
        expect(result).to be_a(BigDecimal)
      end

      it 'XSD-DEC-2: preserves arbitrary precision' do
        result = coerce('123456789.123456789', 'xsd:decimal')
        expect(result).to eq(BigDecimal('123456789.123456789'))
      end
    end

    describe 'float and double' do
      # https://www.w3.org/TR/xmlschema-2/#float
      it 'XSD-FLT-1: xsd:float coerces to Float' do
        result = coerce('3.14', 'xsd:float')
        expect(result).to be_a(Float)
        expect(result).to be_within(0.001).of(3.14)
      end

      # https://www.w3.org/TR/xmlschema-2/#double
      it 'XSD-FLT-2: xsd:double coerces to Float' do
        result = coerce('3.141592653589793', 'xsd:double')
        expect(result).to be_a(Float)
        expect(result).to be_within(1e-15).of(3.141592653589793)
      end
    end

    describe 'dateTime' do
      # https://www.w3.org/TR/xmlschema-2/#dateTime
      it 'XSD-DT-1: dateTime with UTC timezone coerces to Time' do
        result = coerce('2025-01-15T10:30:00Z', 'xsd:dateTime')
        expect(result).to be_a(Time)
        expect(result.year).to eq(2025)
        expect(result.month).to eq(1)
        expect(result.day).to eq(15)
        expect(result.hour).to eq(10)
        expect(result.min).to eq(30)
      end

      # https://www.w3.org/TR/xmlschema-2/#dateTime
      it 'XSD-DT-2: dateTime with offset timezone coerces to Time' do
        result = coerce('2025-06-15T14:30:00+02:00', 'xsd:dateTime')
        expect(result).to be_a(Time)
        expect(result.utc_offset).to eq(7200)
      end

      # https://www.w3.org/TR/xmlschema-2/#dateTime
      it 'XSD-DT-3: dateTime without timezone stays as string' do
        result = coerce('2025-01-15T10:30:00', 'xsd:dateTime')
        expect(result).to eq('2025-01-15T10:30:00')
        expect(result).to be_a(String)
      end
    end

    describe 'date' do
      # https://www.w3.org/TR/xmlschema-2/#date
      it 'XSD-DATE-1: xsd:date coerces to Date' do
        result = coerce('2025-01-15', 'xsd:date')
        expect(result).to be_a(Date)
        expect(result.year).to eq(2025)
        expect(result.month).to eq(1)
        expect(result.day).to eq(15)
      end

      it 'XSD-DATE-2: invalid date stays as string' do
        expect(coerce('not-a-date', 'xsd:date')).to eq('not-a-date')
      end
    end

    describe 'time' do
      # https://www.w3.org/TR/xmlschema-2/#time
      it 'XSD-TIME-1: xsd:time with timezone coerces to Time' do
        result = coerce('10:30:00Z', 'xsd:time')
        expect(result).to be_a(Time)
        expect(result.hour).to eq(10)
        expect(result.min).to eq(30)
      end

      it 'XSD-TIME-2: xsd:time without timezone stays as string' do
        result = coerce('10:30:00', 'xsd:time')
        expect(result).to eq('10:30:00')
      end
    end

    describe 'binary types' do
      # https://www.w3.org/TR/xmlschema-2/#base64Binary
      it 'XSD-B64-1: base64Binary decodes to string' do
        result = coerce('SGVsbG8gV29ybGQ=', 'xsd:base64Binary')
        expect(result).to eq('Hello World')
      end

      # https://www.w3.org/TR/xmlschema-2/#hexBinary
      it 'XSD-HEX-1: hexBinary decodes to string' do
        result = coerce('48656C6C6F', 'xsd:hexBinary')
        expect(result).to eq('Hello')
      end

      it 'XSD-HEX-2: hexBinary is case-insensitive' do
        result = coerce('48656c6c6f', 'xsd:hexBinary')
        expect(result).to eq('Hello')
      end

      it 'XSD-HEX-3: odd-length hex falls back to string' do
        expect(coerce('4865C', 'xsd:hexBinary')).to eq('4865C')
      end
    end

    describe 'string types' do
      # https://www.w3.org/TR/xmlschema-2/#string
      it 'XSD-STR-1: string types preserve value as-is' do
        expect(coerce('hello', 'xsd:string')).to eq('hello')
        expect(coerce('hello', 'xsd:normalizedString')).to eq('hello')
        expect(coerce('hello', 'xsd:token')).to eq('hello')
        expect(coerce('http://example.com', 'xsd:anyURI')).to eq('http://example.com')
      end
    end

    describe 'unknown types' do
      it 'XSD-UNK-1: unrecognized types fall back to string' do
        expect(coerce('value', 'xsd:customType')).to eq('value')
      end

      it 'XSD-UNK-2: nil type falls back to string' do
        expect(coerce('value', nil)).to eq('value')
      end

      it 'XSD-UNK-3: empty value returns empty string' do
        expect(coerce('', 'xsd:int')).to eq('')
      end
    end

    describe 'malformed values' do
      # https://www.w3.org/TR/xmlschema-2/#integer
      it 'XSD-MAL-1: non-numeric integer values fall back to string' do
        expect(coerce('twelve', 'xsd:int')).to eq('twelve')
        expect(coerce('12.5', 'xsd:int')).to eq('12.5')
        expect(coerce('1,000', 'xsd:integer')).to eq('1,000')
      end

      # https://www.w3.org/TR/xmlschema-2/#decimal
      it 'XSD-MAL-2: non-numeric decimal values fall back to string' do
        expect(coerce('twelve', 'xsd:decimal')).to eq('twelve')
      end

      # https://www.w3.org/TR/xmlschema-2/#float
      it 'XSD-MAL-3: non-numeric float values fall back to string' do
        expect(coerce('not-a-number', 'xsd:float')).to eq('not-a-number')
        expect(coerce('not-a-number', 'xsd:double')).to eq('not-a-number')
      end

      # https://www.w3.org/TR/xmlschema-2/#date
      it 'XSD-MAL-4: invalid date values fall back to string' do
        expect(coerce('not-a-date', 'xsd:date')).to eq('not-a-date')
        expect(coerce('2025-13-01', 'xsd:date')).to eq('2025-13-01')
      end

      # https://www.w3.org/TR/xmlschema-2/#dateTime
      it 'XSD-MAL-5: invalid dateTime with timezone falls back to string' do
        expect(coerce('not-a-datetime+00:00', 'xsd:dateTime')).to eq('not-a-datetime+00:00')
      end

      # https://www.w3.org/TR/xmlschema-2/#dateTime
      it 'XSD-MAL-6: dateTime without timezone preserves string (not a coercion failure)' do
        expect(coerce('2025-01-15T10:30:00', 'xsd:dateTime')).to eq('2025-01-15T10:30:00')
      end

      # https://www.w3.org/TR/xmlschema-2/#boolean
      it 'XSD-MAL-7: non-canonical boolean values fall back to string' do
        expect(coerce('TRUE', 'xsd:boolean')).to eq('TRUE')
        expect(coerce('False', 'xsd:boolean')).to eq('False')
        expect(coerce('yes', 'xsd:boolean')).to eq('yes')
        expect(coerce('no', 'xsd:boolean')).to eq('no')
        expect(coerce('2', 'xsd:boolean')).to eq('2')
      end

      # https://www.w3.org/TR/xmlschema-2/#hexBinary
      it 'XSD-MAL-8: invalid hexBinary falls back to string' do
        expect(coerce('ZZZZ', 'xsd:hexBinary')).to eq('ZZZZ')
        expect(coerce('4865C', 'xsd:hexBinary')).to eq('4865C')
      end
    end
  end

  # --------------------------------------------------------------------------
  # Cardinality (Part 1: Structures - minOccurs/maxOccurs)
  # --------------------------------------------------------------------------

  describe 'Cardinality' do
    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-CARD-1: singular element (maxOccurs=1) is parsed as scalar' do
      xml = '<Response><Name>Alice</Name></Response>'
      name_element = schema_element('Name', type: 'xsd:string', singular: true)

      result = WSDL::Response::Parser.parse(xml, schema: [name_element])
      expect(result[:Response][:Name]).to eq('Alice')
      expect(result[:Response][:Name]).not_to be_a(Array)
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-CARD-2: repeating element (maxOccurs>1) with single value is still an array' do
      xml = '<Response><Item>one</Item></Response>'
      item_element = schema_element('Item', type: 'xsd:string', singular: false)

      result = WSDL::Response::Parser.parse(xml, schema: [item_element])
      expect(result[:Response][:Item]).to eq(['one'])
      expect(result[:Response][:Item]).to be_a(Array)
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-CARD-3: repeating element with multiple values produces array' do
      xml = '<Response><Item>one</Item><Item>two</Item><Item>three</Item></Response>'
      item_element = schema_element('Item', type: 'xsd:string', singular: false)

      result = WSDL::Response::Parser.parse(xml, schema: [item_element])
      expect(result[:Response][:Item]).to eq(%w[one two three])
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-CARD-4: optional element (minOccurs=0) absent from response is omitted from hash' do
      xml = '<Response><Name>Alice</Name></Response>'
      name_element = schema_element('Name', type: 'xsd:string')
      age_element = schema_element('Age', type: 'xsd:int')

      result = WSDL::Response::Parser.parse(xml, schema: [name_element, age_element])
      expect(result[:Response]).to eq({ Name: 'Alice' })
      expect(result[:Response]).not_to have_key(:Age)
    end
  end

  # --------------------------------------------------------------------------
  # Nillability (Part 1: Structures - xsi:nil)
  # --------------------------------------------------------------------------

  describe 'Nillability' do
    # https://www.w3.org/TR/xmlschema-1/#xsi_nil
    it 'XSD-NIL-1: xsi:nil="true" produces nil for simple type elements' do
      xml = '<Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \
            '<Name xsi:nil="true"/></Response>'
      name_element = schema_element('Name', type: 'xsd:string')

      result = WSDL::Response::Parser.parse(xml, schema: [name_element])
      expect(result[:Response][:Name]).to be_nil
    end

    # https://www.w3.org/TR/xmlschema-1/#xsi_nil
    it 'XSD-NIL-2: xsi:nil="true" produces nil for complex type elements' do
      child = schema_element('Street', type: 'xsd:string')
      address = schema_element('Address', children: [child])

      xml = '<Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \
            '<Address xsi:nil="true"/></Response>'

      result = WSDL::Response::Parser.parse(xml, schema: [address])
      expect(result[:Response][:Address]).to be_nil
    end

    # https://www.w3.org/TR/xmlschema-1/#xsi_nil
    it 'XSD-NIL-3: element without xsi:nil is not treated as nil' do
      xml = '<Response><Name></Name></Response>'
      name_element = schema_element('Name', type: 'xsd:string')

      result = WSDL::Response::Parser.parse(xml, schema: [name_element])
      expect(result[:Response][:Name]).to eq('')
    end
  end

  # --------------------------------------------------------------------------
  # Form Qualification (Part 1: Structures - elementFormDefault)
  # --------------------------------------------------------------------------

  describe 'Form Qualification' do
    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-FORM-1: qualified elements match by namespace and local name' do
      xml = '<ns:Response xmlns:ns="http://example.com">' \
            '<ns:Name>Alice</ns:Name></ns:Response>'

      name_element = schema_element('Name', type: 'xsd:string',
        namespace: 'http://example.com', form: 'qualified')

      result = WSDL::Response::Parser.parse(xml, schema: [name_element])
      expect(result[:Response][:Name]).to eq('Alice')
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-FORM-2: unqualified elements match by local name only' do
      xml = '<ns:Response xmlns:ns="http://example.com">' \
            '<Name>Alice</Name></ns:Response>'

      name_element = schema_element('Name', type: 'xsd:string',
        namespace: nil, form: 'unqualified')

      result = WSDL::Response::Parser.parse(xml, schema: [name_element])
      expect(result[:Response][:Name]).to eq('Alice')
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-FORM-3: mixed qualified and unqualified elements in same response' do
      qualified_child = schema_element(
        'Id', type: 'xsd:int', namespace: 'http://example.com', form: 'qualified'
      )
      unqualified_child = schema_element(
        'Name', type: 'xsd:string', namespace: nil, form: 'unqualified'
      )
      wrapper = schema_element(
        'User', children: [qualified_child, unqualified_child],
        namespace: 'http://example.com', form: 'qualified'
      )

      xml = '<ns:Response xmlns:ns="http://example.com">' \
            '<ns:User><ns:Id>42</ns:Id><Name>Alice</Name></ns:User></ns:Response>'

      result = WSDL::Response::Parser.parse(xml, schema: [wrapper])
      expect(result[:Response][:User][:Id]).to eq(42)
      expect(result[:Response][:User][:Id]).to be_a(Integer)
      expect(result[:Response][:User][:Name]).to eq('Alice')
    end
  end

  # --------------------------------------------------------------------------
  # Type Inheritance (Part 1: Structures - xs:extension)
  # --------------------------------------------------------------------------

  describe 'Type Inheritance' do
    let(:definition) { WSDL::Parser.parse fixture('wsdl/oracle'), http_mock }
    let(:op_data) { definition.operation_data('WebCatalogService', 'WebCatalogServiceSoap', 'updateCatalogItemACL') }

    # UpdateCatalogItemACLParams extends UpdateACLParams:
    #   base  (UpdateACLParams):             updateFlag (xsd:string via simpleType)
    #   derived (UpdateCatalogItemACLParams): recursive  (xsd:boolean)
    #
    # The "options" parameter in updateCatalogItemACL uses the derived type,
    # so its children must include elements from both base and derived.

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-EXT-1: derived type includes its own elements' do
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      options = find_child_element(body_parts.first, 'options')

      expect(options).to be_complex_type
      child_names = options.children.map(&:name)
      expect(child_names).to include('recursive')
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-EXT-2: derived type includes inherited elements from base type' do
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      options = find_child_element(body_parts.first, 'options')

      child_names = options.children.map(&:name)
      expect(child_names).to include('updateFlag')
    end

    # https://www.w3.org/TR/xmlschema-1/#declare-element
    it 'XSD-EXT-3: base type elements appear before derived type elements' do
      body_parts = op_data[:input][:body].map { |h| WSDL::Definition::ElementHash.new(h) }
      options = find_child_element(body_parts.first, 'options')

      child_names = options.children.map(&:name)
      flag_index = child_names.index('updateFlag')
      recursive_index = child_names.index('recursive')

      expect(flag_index).to be < recursive_index
    end
  end

  private

  def find_child_element(element, name)
    element.children.each do |child|
      return child if child.name == name

      if child.complex_type?
        found = find_child_element(child, name)
        return found if found
      end
    end
    nil
  end
end
