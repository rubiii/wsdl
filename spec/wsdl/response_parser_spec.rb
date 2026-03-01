# frozen_string_literal: true

require 'spec_helper'

describe WSDL::ResponseParser, type: :unit do
  include SchemaElementHelper

  def soap_envelope(body_content)
    <<~XML
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
          #{body_content}
        </soap:Body>
      </soap:Envelope>
    XML
  end

  describe '#parse' do
    context 'with string types' do
      it 'parses xsd:string as String' do
        schema = [schema_element('Name', type: 'xsd:string')]
        xml = soap_envelope('<Name>John Doe</Name>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Name: 'John Doe' })
      end

      it 'parses xsd:anyURI as String' do
        schema = [schema_element('Url', type: 'xsd:anyURI')]
        xml = soap_envelope('<Url>https://example.com</Url>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Url: 'https://example.com' })
      end

      it 'parses xsd:token as String' do
        schema = [schema_element('Token', type: 'xsd:token')]
        xml = soap_envelope('<Token>abc123</Token>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Token: 'abc123' })
      end
    end

    context 'with integer types' do
      it 'parses xsd:int as Integer' do
        schema = [schema_element('Count', type: 'xsd:int')]
        xml = soap_envelope('<Count>42</Count>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Count: 42 })
        expect(result[:Count]).to be_a(Integer)
      end

      it 'parses xsd:integer as Integer' do
        schema = [schema_element('Id', type: 'xsd:integer')]
        xml = soap_envelope('<Id>123456789</Id>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Id: 123_456_789 })
        expect(result[:Id]).to be_a(Integer)
      end

      it 'parses xsd:long as Integer' do
        schema = [schema_element('BigNumber', type: 'xsd:long')]
        xml = soap_envelope('<BigNumber>9223372036854775807</BigNumber>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:BigNumber]).to eq(9_223_372_036_854_775_807)
        expect(result[:BigNumber]).to be_a(Integer)
      end

      it 'parses xsd:short as Integer' do
        schema = [schema_element('SmallNumber', type: 'xsd:short')]
        xml = soap_envelope('<SmallNumber>32767</SmallNumber>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:SmallNumber]).to eq(32_767)
      end

      it 'parses xsd:byte as Integer' do
        schema = [schema_element('TinyNumber', type: 'xsd:byte')]
        xml = soap_envelope('<TinyNumber>127</TinyNumber>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:TinyNumber]).to eq(127)
      end

      it 'parses negative integers' do
        schema = [schema_element('Balance', type: 'xsd:int')]
        xml = soap_envelope('<Balance>-500</Balance>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Balance]).to eq(-500)
      end

      it 'parses xsd:unsignedInt as Integer' do
        schema = [schema_element('Positive', type: 'xsd:unsignedInt')]
        xml = soap_envelope('<Positive>4294967295</Positive>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Positive]).to eq(4_294_967_295)
      end

      it 'returns original string for invalid integer' do
        schema = [schema_element('Count', type: 'xsd:int')]
        xml = soap_envelope('<Count>not-a-number</Count>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Count]).to eq('not-a-number')
      end
    end

    context 'with decimal types' do
      it 'parses xsd:decimal as BigDecimal' do
        schema = [schema_element('Price', type: 'xsd:decimal')]
        xml = soap_envelope('<Price>99.99</Price>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Price]).to eq(BigDecimal('99.99'))
        expect(result[:Price]).to be_a(BigDecimal)
      end

      it 'parses xsd:decimal with high precision' do
        schema = [schema_element('Amount', type: 'xsd:decimal')]
        xml = soap_envelope('<Amount>123456.78901234567890</Amount>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Amount]).to eq(BigDecimal('123456.78901234567890'))
      end

      it 'returns original string for invalid decimal' do
        schema = [schema_element('Price', type: 'xsd:decimal')]
        xml = soap_envelope('<Price>invalid</Price>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Price]).to eq('invalid')
      end
    end

    context 'with float types' do
      it 'parses xsd:float as Float' do
        schema = [schema_element('Rate', type: 'xsd:float')]
        xml = soap_envelope('<Rate>3.14159</Rate>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Rate]).to be_within(0.00001).of(3.14159)
        expect(result[:Rate]).to be_a(Float)
      end

      it 'parses xsd:double as Float' do
        schema = [schema_element('Precision', type: 'xsd:double')]
        xml = soap_envelope('<Precision>1.7976931348623157E+308</Precision>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Precision]).to be_a(Float)
      end

      it 'parses scientific notation' do
        schema = [schema_element('Scientific', type: 'xsd:float')]
        xml = soap_envelope('<Scientific>1.23e-4</Scientific>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Scientific]).to be_within(0.000001).of(0.000123)
      end

      it 'returns original string for invalid float' do
        schema = [schema_element('Rate', type: 'xsd:float')]
        xml = soap_envelope('<Rate>not-a-float</Rate>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Rate]).to eq('not-a-float')
      end
    end

    context 'with boolean type' do
      it 'parses "true" as true' do
        schema = [schema_element('Active', type: 'xsd:boolean')]
        xml = soap_envelope('<Active>true</Active>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Active]).to be true
      end

      it 'parses "false" as false' do
        schema = [schema_element('Active', type: 'xsd:boolean')]
        xml = soap_envelope('<Active>false</Active>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Active]).to be false
      end

      it 'parses "1" as true' do
        schema = [schema_element('Enabled', type: 'xsd:boolean')]
        xml = soap_envelope('<Enabled>1</Enabled>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Enabled]).to be true
      end

      it 'parses "0" as false' do
        schema = [schema_element('Enabled', type: 'xsd:boolean')]
        xml = soap_envelope('<Enabled>0</Enabled>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Enabled]).to be false
      end

      it 'parses other values as false' do
        schema = [schema_element('Active', type: 'xsd:boolean')]
        xml = soap_envelope('<Active>yes</Active>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Active]).to be false
      end
    end

    context 'with date types' do
      it 'parses xsd:date as Date' do
        schema = [schema_element('BirthDate', type: 'xsd:date')]
        xml = soap_envelope('<BirthDate>2024-01-15</BirthDate>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:BirthDate]).to eq(Date.new(2024, 1, 15))
        expect(result[:BirthDate]).to be_a(Date)
      end

      it 'returns original string for invalid date' do
        schema = [schema_element('BirthDate', type: 'xsd:date')]
        xml = soap_envelope('<BirthDate>not-a-date</BirthDate>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:BirthDate]).to eq('not-a-date')
      end
    end

    context 'with datetime types' do
      it 'parses xsd:dateTime as Time' do
        schema = [schema_element('CreatedAt', type: 'xsd:dateTime')]
        xml = soap_envelope('<CreatedAt>2024-01-15T10:30:00Z</CreatedAt>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:CreatedAt]).to be_a(Time)
        expect(result[:CreatedAt].year).to eq(2024)
        expect(result[:CreatedAt].month).to eq(1)
        expect(result[:CreatedAt].day).to eq(15)
      end

      it 'parses xsd:dateTime with timezone offset' do
        schema = [schema_element('Timestamp', type: 'xsd:dateTime')]
        xml = soap_envelope('<Timestamp>2024-01-15T10:30:00+05:30</Timestamp>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Timestamp]).to be_a(Time)
      end

      it 'returns original string for invalid datetime' do
        schema = [schema_element('CreatedAt', type: 'xsd:dateTime')]
        xml = soap_envelope('<CreatedAt>invalid-datetime</CreatedAt>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:CreatedAt]).to eq('invalid-datetime')
      end
    end

    context 'with time type' do
      it 'parses xsd:time as Time' do
        schema = [schema_element('StartTime', type: 'xsd:time')]
        xml = soap_envelope('<StartTime>14:30:00</StartTime>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:StartTime]).to be_a(Time)
        expect(result[:StartTime].hour).to eq(14)
        expect(result[:StartTime].min).to eq(30)
      end
    end

    context 'with binary types' do
      it 'parses xsd:base64Binary and decodes it' do
        schema = [schema_element('Data', type: 'xsd:base64Binary')]
        xml = soap_envelope('<Data>SGVsbG8gV29ybGQ=</Data>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Data]).to eq('Hello World')
      end

      it 'parses xsd:hexBinary and decodes it' do
        schema = [schema_element('HexData', type: 'xsd:hexBinary')]
        xml = soap_envelope('<HexData>48656C6C6F</HexData>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:HexData]).to eq('Hello')
      end
    end

    context 'with empty values' do
      it 'returns empty string for empty element' do
        schema = [schema_element('Name', type: 'xsd:string')]
        xml = soap_envelope('<Name></Name>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Name]).to eq('')
      end

      it 'returns empty string for self-closing element' do
        schema = [schema_element('Name', type: 'xsd:string')]
        xml = soap_envelope('<Name/>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Name]).to eq('')
      end
    end

    context 'with xsi:nil' do
      it 'returns nil for element with xsi:nil="true"' do
        schema = [schema_element('Value', type: 'xsd:string', nillable: true)]
        xml = soap_envelope('<Value xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true"/>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Value]).to be_nil
      end

      it 'returns value when xsi:nil is not true' do
        schema = [schema_element('Value', type: 'xsd:string')]
        xml = soap_envelope('<Value xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="false">test</Value>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Value]).to eq('test')
      end
    end

    context 'with array handling (maxOccurs)' do
      it 'returns single value when singular is true and one element present' do
        schema = [schema_element('Item', type: 'xsd:string', singular: true)]
        xml = soap_envelope('<Item>one</Item>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Item]).to eq('one')
        expect(result[:Item]).not_to be_an(Array)
      end

      it 'returns array when singular is false and one element present' do
        schema = [schema_element('Item', type: 'xsd:string', singular: false)]
        xml = soap_envelope('<Item>one</Item>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Item]).to eq(['one'])
        expect(result[:Item]).to be_an(Array)
      end

      it 'returns array when singular is false and multiple elements present' do
        schema = [schema_element('Item', type: 'xsd:string', singular: false)]
        xml = soap_envelope('<Item>one</Item><Item>two</Item><Item>three</Item>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Item]).to eq(%w[one two three])
      end

      it 'handles array of integers' do
        schema = [schema_element('Id', type: 'xsd:int', singular: false)]
        xml = soap_envelope('<Id>1</Id><Id>2</Id><Id>3</Id>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Id]).to eq([1, 2, 3])
        expect(result[:Id]).to all(be_an(Integer))
      end

      it 'handles array of complex types' do
        name_element = schema_element('Name', type: 'xsd:string')
        age_element = schema_element('Age', type: 'xsd:int')
        user_element = schema_element('User', children: [name_element, age_element], singular: false)
        schema = [user_element]

        xml = soap_envelope(<<~BODY)
          <User><Name>Alice</Name><Age>30</Age></User>
          <User><Name>Bob</Name><Age>25</Age></User>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:User]).to eq([
          { Name: 'Alice', Age: 30 },
          { Name: 'Bob', Age: 25 }
        ])
      end
    end

    context 'with complex types' do
      it 'parses nested elements' do
        name_element = schema_element('Name', type: 'xsd:string')
        email_element = schema_element('Email', type: 'xsd:string')
        user_element = schema_element('User', children: [name_element, email_element])
        schema = [user_element]

        xml = soap_envelope(<<~BODY)
          <User>
            <Name>John Doe</Name>
            <Email>john@example.com</Email>
          </User>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({
          User: {
            Name: 'John Doe',
            Email: 'john@example.com'
          }
        })
      end

      it 'parses deeply nested elements' do
        street_element = schema_element('Street', type: 'xsd:string')
        city_element = schema_element('City', type: 'xsd:string')
        zip_element = schema_element('Zip', type: 'xsd:int')
        address_element = schema_element('Address', children: [street_element, city_element, zip_element])

        name_element = schema_element('Name', type: 'xsd:string')
        user_element = schema_element('User', children: [name_element, address_element])
        schema = [user_element]

        xml = soap_envelope(<<~BODY)
          <User>
            <Name>Jane</Name>
            <Address>
              <Street>123 Main St</Street>
              <City>Springfield</City>
              <Zip>12345</Zip>
            </Address>
          </User>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({
          User: {
            Name: 'Jane',
            Address: {
              Street: '123 Main St',
              City: 'Springfield',
              Zip: 12_345
            }
          }
        })
      end

      it 'handles mixed simple and complex children' do
        id_element = schema_element('Id', type: 'xsd:int')
        line_element = schema_element('Line', type: 'xsd:string', singular: false)
        address_element = schema_element('Address', children: [line_element])

        schema = [id_element, address_element]

        xml = soap_envelope(<<~BODY)
          <Id>42</Id>
          <Address>
            <Line>123 Main St</Line>
            <Line>Suite 100</Line>
          </Address>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({
          Id: 42,
          Address: {
            Line: ['123 Main St', 'Suite 100']
          }
        })
      end
    end

    context 'with unknown elements (not in schema)' do
      it 'includes unknown elements as strings' do
        schema = [schema_element('Known', type: 'xsd:string')]
        xml = soap_envelope('<Known>expected</Known><Unknown>extra</Unknown>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Known]).to eq('expected')
        expect(result[:Unknown]).to eq('extra')
      end

      it 'includes unknown nested elements as hash' do
        schema = [schema_element('Known', type: 'xsd:string')]
        xml = soap_envelope(<<~BODY)
          <Known>expected</Known>
          <Unknown>
            <Child1>value1</Child1>
            <Child2>value2</Child2>
          </Unknown>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Known]).to eq('expected')
        expect(result[:Unknown]).to eq({
          Child1: 'value1',
          Child2: 'value2'
        })
      end

      it 'converts unknown repeated elements to arrays' do
        schema = [schema_element('Known', type: 'xsd:string')]
        xml = soap_envelope('<Known>expected</Known><Unknown>one</Unknown><Unknown>two</Unknown>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Unknown]).to eq(%w[one two])
      end
    end

    context 'with unknown types' do
      it 'returns value as string for unknown type' do
        schema = [schema_element('Custom', type: 'custom:MyType')]
        xml = soap_envelope('<Custom>some value</Custom>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Custom]).to eq('some value')
      end
    end

    context 'with element name preservation' do
      it 'preserves PascalCase names' do
        schema = [schema_element('UserName', type: 'xsd:string')]
        xml = soap_envelope('<UserName>johndoe</UserName>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to have_key(:UserName)
      end

      it 'preserves camelCase names' do
        schema = [schema_element('firstName', type: 'xsd:string')]
        xml = soap_envelope('<firstName>John</firstName>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to have_key(:firstName)
      end

      it 'preserves acronyms' do
        schema = [schema_element('XMLData', type: 'xsd:string')]
        xml = soap_envelope('<XMLData>content</XMLData>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to have_key(:XMLData)
      end

      it 'preserves hyphens in names' do
        schema = [schema_element('first-name', type: 'xsd:string')]
        xml = soap_envelope('<first-name>John</first-name>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to have_key(:'first-name')
      end
    end

    context 'with SOAP 1.2 envelope' do
      it 'finds body in SOAP 1.2 namespace' do
        schema = [schema_element('Result', type: 'xsd:string')]
        xml = <<~XML
          <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
            <soap:Body>
              <Result>success</Result>
            </soap:Body>
          </soap:Envelope>
        XML
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Result]).to eq('success')
      end
    end

    context 'with missing elements' do
      it 'skips elements not present in response' do
        schema = [
          schema_element('Present', type: 'xsd:string'),
          schema_element('Missing', type: 'xsd:string')
        ]
        xml = soap_envelope('<Present>here</Present>')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({ Present: 'here' })
        expect(result).not_to have_key(:Missing)
      end
    end

    context 'with empty body' do
      it 'returns empty hash for empty body' do
        schema = [schema_element('Result', type: 'xsd:string')]
        xml = soap_envelope('')
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({})
      end
    end

    context 'with namespaced elements' do
      it 'parses elements with namespace prefixes' do
        schema = [schema_element('Result', type: 'xsd:string')]
        xml = <<~XML
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <ns1:Result xmlns:ns1="http://example.com">success</ns1:Result>
            </soap:Body>
          </soap:Envelope>
        XML
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result[:Result]).to eq('success')
      end
    end

    context 'real-world scenario' do
      it 'parses a complete order response' do
        # Define schema structure
        id_element = schema_element('Id', type: 'xsd:int')
        name_element = schema_element('Name', type: 'xsd:string')
        price_element = schema_element('Price', type: 'xsd:decimal')
        quantity_element = schema_element('Quantity', type: 'xsd:int')

        item_element = schema_element(
          'Item',
          children: [name_element, price_element, quantity_element],
          singular: false
        )
        items_element = schema_element('Items', children: [item_element])

        order_date_element = schema_element('OrderDate', type: 'xsd:date')
        shipped_element = schema_element('Shipped', type: 'xsd:boolean')
        total_element = schema_element('Total', type: 'xsd:decimal')

        order_element = schema_element('Order', children: [
          id_element, order_date_element, shipped_element, total_element, items_element
        ])

        response_element = schema_element('GetOrderResponse', children: [order_element])
        schema = [response_element]

        xml = soap_envelope(<<~BODY)
          <GetOrderResponse>
            <Order>
              <Id>12345</Id>
              <OrderDate>2024-01-15</OrderDate>
              <Shipped>true</Shipped>
              <Total>149.97</Total>
              <Items>
                <Item>
                  <Name>Widget</Name>
                  <Price>49.99</Price>
                  <Quantity>3</Quantity>
                </Item>
              </Items>
            </Order>
          </GetOrderResponse>
        BODY
        doc = Nokogiri::XML(xml)

        result = described_class.new(schema).parse(doc)

        expect(result).to eq({
          GetOrderResponse: {
            Order: {
              Id: 12_345,
              OrderDate: Date.new(2024, 1, 15),
              Shipped: true,
              Total: BigDecimal('149.97'),
              Items: {
                Item: [
                  {
                    Name: 'Widget',
                    Price: BigDecimal('49.99'),
                    Quantity: 3
                  }
                ]
              }
            }
          }
        })
      end
    end
  end
end
