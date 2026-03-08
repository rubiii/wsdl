# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Response::Parser do
  include SchemaElementHelper

  describe '.parse without schema' do
    it 'parses an XML string into a Hash' do
      xml = '<Root><Child>content</Child></Root>'
      result = described_class.parse(xml)

      expect(result).to eq({ Root: { Child: 'content' } })
    end

    it 'parses a Nokogiri::XML::Document' do
      xml = '<Root><Child>content</Child></Root>'
      doc = Nokogiri::XML(xml)
      result = described_class.parse(doc)

      expect(result).to eq({ Root: { Child: 'content' } })
    end

    it 'parses a Nokogiri::XML::Node' do
      xml = '<Root><Parent><Child>content</Child></Parent></Root>'
      doc = Nokogiri::XML(xml)
      node = doc.at_xpath('//Parent')
      result = described_class.parse(node)

      expect(result).to eq({ Parent: { Child: 'content' } })
    end

    it 'preserves element names as-is' do
      xml = '<GetUserResponse><UserName>John</UserName></GetUserResponse>'
      result = described_class.parse(xml)

      expect(result).to eq({ GetUserResponse: { UserName: 'John' } })
    end

    it 'preserves acronyms in element names' do
      xml = '<XMLParser><HTTPResponse>OK</HTTPResponse></XMLParser>'
      result = described_class.parse(xml)

      expect(result).to eq({ XMLParser: { HTTPResponse: 'OK' } })
    end

    it 'preserves hyphens in element names' do
      xml = '<my-element><nested-child>value</nested-child></my-element>'
      result = described_class.parse(xml)

      expect(result).to eq({ 'my-element': { 'nested-child': 'value' } })
    end

    it 'strips namespace prefixes from element names' do
      xml = '<soap:Envelope xmlns:soap="http://example.com"><soap:Body>content</soap:Body></soap:Envelope>'
      result = described_class.parse(xml)

      expect(result).to eq({ Envelope: { Body: 'content' } })
    end

    it 'returns text content for leaf nodes' do
      xml = '<Root>just text</Root>'
      result = described_class.parse(xml)

      expect(result).to eq({ Root: 'just text' })
    end

    it 'returns empty string for empty leaf nodes' do
      xml = '<Root><Empty></Empty></Root>'
      result = described_class.parse(xml)

      expect(result).to eq({ Root: { Empty: '' } })
    end

    it 'handles deeply nested structures' do
      xml = '<A><B><C><D>deep</D></C></B></A>'
      result = described_class.parse(xml)

      expect(result).to eq({ A: { B: { C: { D: 'deep' } } } })
    end

    it 'returns an empty hash for nil input' do
      expect(described_class.parse(nil)).to eq({})
    end

    describe 'with unwrap: true' do
      it 'returns the root value without the root key wrapper' do
        xml = '<Root><Child>content</Child></Root>'

        expect(described_class.parse(xml, unwrap: true)).to eq({ Child: 'content' })
      end
    end

    context 'with repeated elements' do
      it 'converts repeated elements into arrays' do
        xml = '<Root><Item>one</Item><Item>two</Item><Item>three</Item></Root>'
        result = described_class.parse(xml)

        expect(result).to eq({ Root: { Item: %w[one two three] } })
      end

      it 'handles mixed single and repeated elements' do
        xml = '<Root><Single>only</Single><Item>one</Item><Item>two</Item></Root>'
        result = described_class.parse(xml)

        expect(result).to eq({ Root: { Single: 'only', Item: %w[one two] } })
      end

      it 'handles repeated complex elements' do
        xml = <<-XML
          <Root>
            <User><Name>Alice</Name></User>
            <User><Name>Bob</Name></User>
          </Root>
        XML
        result = described_class.parse(xml)

        expect(result).to eq({
          Root: {
            User: [
              { Name: 'Alice' },
              { Name: 'Bob' }
            ]
          }
        })
      end
    end

    context 'with local-name collisions across namespaces' do
      it 'disambiguates unknown elements with Clark notation keys' do
        xml = <<-XML
          <Root xmlns:a="urn:a" xmlns:b="urn:b">
            <a:Value>one</a:Value>
            <b:Value>two</b:Value>
          </Root>
        XML

        result = described_class.parse(xml)

        expect(result).to eq({
          Root: {
            '{urn:a}Value': 'one',
            '{urn:b}Value': 'two'
          }
        })
      end

      it 'keeps local-name key for non-namespaced element when mixed with namespaced one' do
        xml = <<-XML
          <Root xmlns:a="urn:a">
            <Value>local</Value>
            <a:Value>namespaced</a:Value>
          </Root>
        XML

        result = described_class.parse(xml)

        expect(result).to eq({
          Root: {
            Value: 'local',
            '{urn:a}Value': 'namespaced'
          }
        })
      end
    end

    context 'with SOAP envelopes' do
      let(:soap_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
              <SessionId>abc123</SessionId>
            </env:Header>
            <env:Body>
              <GetUserResponse>
                <User>
                  <Id>1</Id>
                  <Name>John Doe</Name>
                </User>
              </GetUserResponse>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'parses a complete SOAP envelope' do
        result = described_class.parse(soap_xml)

        expect(result).to eq({
          Envelope: {
            Header: { SessionId: 'abc123' },
            Body: {
              GetUserResponse: {
                User: {
                  Id: '1',
                  Name: 'John Doe'
                }
              }
            }
          }
        })
      end
    end
  end

  describe '.parse with schema' do
    it 'converts integer types to Integer' do
      xml = '<Response><Count>42</Count></Response>'
      count_element = schema_element('Count', type: 'xsd:int')
      schema = [count_element]

      result = described_class.parse(xml, schema:)

      expect(result).to eq({ Response: { Count: 42 } })
      expect(result[:Response][:Count]).to be_a(Integer)
    end

    it 'converts decimal types to BigDecimal' do
      xml = '<Response><Price>99.99</Price></Response>'
      price_element = schema_element('Price', type: 'xsd:decimal')
      schema = [price_element]

      result = described_class.parse(xml, schema:)

      expect(result).to eq({ Response: { Price: BigDecimal('99.99') } })
      expect(result[:Response][:Price]).to be_a(BigDecimal)
    end

    it 'converts float types to Float' do
      xml = '<Response><Ratio>3.14159</Ratio></Response>'
      ratio_element = schema_element('Ratio', type: 'xsd:double')
      schema = [ratio_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:Ratio]).to be_a(Float)
      expect(result[:Response][:Ratio]).to be_within(0.00001).of(3.14159)
    end

    it 'converts boolean types to true/false' do
      xml = '<Response><Active>true</Active><Deleted>false</Deleted></Response>'
      active_element = schema_element('Active', type: 'xsd:boolean')
      deleted_element = schema_element('Deleted', type: 'xsd:boolean')
      schema = [active_element, deleted_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:Active]).to be true
      expect(result[:Response][:Deleted]).to be false
    end

    it 'converts boolean "1" to true and "0" to false' do
      xml = '<Response><Yes>1</Yes><No>0</No></Response>'
      yes_element = schema_element('Yes', type: 'xsd:boolean')
      no_element = schema_element('No', type: 'xsd:boolean')
      schema = [yes_element, no_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:Yes]).to be true
      expect(result[:Response][:No]).to be false
    end

    it 'converts date types to Date' do
      xml = '<Response><BirthDate>2024-01-15</BirthDate></Response>'
      date_element = schema_element('BirthDate', type: 'xsd:date')
      schema = [date_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:BirthDate]).to eq(Date.new(2024, 1, 15))
      expect(result[:Response][:BirthDate]).to be_a(Date)
    end

    it 'converts dateTime types to Time' do
      xml = '<Response><CreatedAt>2024-01-15T10:30:00Z</CreatedAt></Response>'
      datetime_element = schema_element('CreatedAt', type: 'xsd:dateTime')
      schema = [datetime_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:CreatedAt]).to be_a(Time)
      expect(result[:Response][:CreatedAt].year).to eq(2024)
      expect(result[:Response][:CreatedAt].month).to eq(1)
      expect(result[:Response][:CreatedAt].day).to eq(15)
    end

    it 'keeps dateTime without timezone as string' do
      xml = '<Response><CreatedAt>2024-01-15T10:30:00</CreatedAt></Response>'
      datetime_element = schema_element('CreatedAt', type: 'xsd:dateTime')
      schema = [datetime_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:CreatedAt]).to eq('2024-01-15T10:30:00')
    end

    it 'keeps time without timezone as string' do
      xml = '<Response><TimeOfDay>10:30:00</TimeOfDay></Response>'
      time_element = schema_element('TimeOfDay', type: 'xsd:time')
      schema = [time_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:TimeOfDay]).to eq('10:30:00')
    end

    it 'converts base64Binary types to decoded string' do
      xml = '<Response><Data>SGVsbG8gV29ybGQ=</Data></Response>'
      data_element = schema_element('Data', type: 'xsd:base64Binary')
      schema = [data_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:Data]).to eq('Hello World')
    end

    it 'converts hexBinary types to decoded string' do
      xml = '<Response><Data>48656C6C6F</Data></Response>'
      data_element = schema_element('Data', type: 'xsd:hexBinary')
      schema = [data_element]

      result = described_class.parse(xml, schema:)

      expect(result[:Response][:Data]).to eq('Hello')
    end

    context 'array handling based on maxOccurs' do
      it 'returns array when schema says singular: false, even with single element' do
        xml = '<Response><Item>only-one</Item></Response>'
        item_element = schema_element('Item', type: 'xsd:string', singular: false)
        schema = [item_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Item]).to eq(['only-one'])
        expect(result[:Response][:Item]).to be_an(Array)
      end

      it 'returns single value when schema says singular: true' do
        xml = '<Response><Item>only-one</Item></Response>'
        item_element = schema_element('Item', type: 'xsd:string', singular: true)
        schema = [item_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Item]).to eq('only-one')
        expect(result[:Response][:Item]).not_to be_an(Array)
      end

      it 'returns array with multiple elements when singular: false' do
        xml = '<Response><Item>one</Item><Item>two</Item><Item>three</Item></Response>'
        item_element = schema_element('Item', type: 'xsd:string', singular: false)
        schema = [item_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Item]).to eq(%w[one two three])
      end
    end

    context 'with complex types' do
      it 'handles nested complex types' do
        xml = <<-XML
          <Response>
            <User>
              <Name>Alice</Name>
              <Age>30</Age>
            </User>
          </Response>
        XML

        name_element = schema_element('Name', type: 'xsd:string')
        age_element = schema_element('Age', type: 'xsd:int')
        user_element = schema_element('User', children: [name_element, age_element])
        schema = [user_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:User]).to eq({ Name: 'Alice', Age: 30 })
        expect(result[:Response][:User][:Age]).to be_a(Integer)
      end

      it 'handles arrays of complex types' do
        xml = <<-XML
          <Response>
            <User>
              <Name>Alice</Name>
              <Age>30</Age>
            </User>
            <User>
              <Name>Bob</Name>
              <Age>25</Age>
            </User>
          </Response>
        XML

        name_element = schema_element('Name', type: 'xsd:string')
        age_element = schema_element('Age', type: 'xsd:int')
        user_element = schema_element('User', children: [name_element, age_element], singular: false)
        schema = [user_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:User]).to eq([
          { Name: 'Alice', Age: 30 },
          { Name: 'Bob', Age: 25 }
        ])
      end

      it 'returns text for complex elements with no child schema' do
        xml = '<Body><Response>raw-content</Response></Body>'
        response_element = instance_double(
          WSDL::XML::Element,
          name: 'Response',
          singular?: true,
          nillable?: false,
          children: [],
          namespace: nil,
          form: 'qualified',
          simple_type?: false,
          complex_type?: true,
          base_type: nil
        )

        result = described_class.parse(xml, schema: [response_element])

        expect(result).to eq({ Body: { Response: 'raw-content' } })
      end
    end

    context 'with xsi:nil' do
      it 'returns nil for element with xsi:nil="true"' do
        xml = '<Response><Value xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true"/></Response>'
        value_element = schema_element('Value', type: 'xsd:string', nillable: true)
        schema = [value_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Value]).to be_nil
      end
    end

    context 'with unknown elements not in schema' do
      it 'includes unknown elements as strings' do
        xml = '<Response><Known>expected</Known><Unknown>extra</Unknown></Response>'
        known_element = schema_element('Known', type: 'xsd:string')
        schema = [known_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Known]).to eq('expected')
        expect(result[:Response][:Unknown]).to eq('extra')
      end

      it 'handles unknown complex elements as hashes' do
        xml = <<-XML
          <Response>
            <Known>expected</Known>
            <Unknown>
              <Nested>value</Nested>
            </Unknown>
          </Response>
        XML
        known_element = schema_element('Known', type: 'xsd:string')
        schema = [known_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Unknown]).to eq({ Nested: 'value' })
      end

      it 'disambiguates mixed known/unknown elements with same local name across namespaces' do
        xml = <<-XML
          <Response xmlns:a="urn:a" xmlns:b="urn:b">
            <a:Value>42</a:Value>
            <b:Value>extra</b:Value>
          </Response>
        XML
        known_element = schema_element('Value', type: 'xsd:int', namespace: 'urn:a')
        schema = [known_element]

        result = described_class.parse(xml, schema:)

        expect(result).to eq({
          Response: {
            '{urn:a}Value': 42,
            '{urn:b}Value': 'extra'
          }
        })
      end
    end

    context 'with schema elements that share local names across namespaces' do
      it 'matches elements by namespace plus local name' do
        xml = <<-XML
          <Response xmlns:a="urn:a" xmlns:b="urn:b">
            <a:Value>1</a:Value>
            <b:Value>2</b:Value>
          </Response>
        XML
        first = schema_element('Value', type: 'xsd:int', namespace: 'urn:a')
        second = schema_element('Value', type: 'xsd:int', namespace: 'urn:b')

        result = described_class.parse(xml, schema: [first, second])

        expect(result).to eq({
          Response: {
            '{urn:a}Value': 1,
            '{urn:b}Value': 2
          }
        })
      end
    end

    context 'with invalid values' do
      it 'returns original string when integer conversion fails' do
        xml = '<Response><Count>not-a-number</Count></Response>'
        count_element = schema_element('Count', type: 'xsd:int')
        schema = [count_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Count]).to eq('not-a-number')
      end

      it 'returns original string when date conversion fails' do
        xml = '<Response><Date>invalid-date</Date></Response>'
        date_element = schema_element('Date', type: 'xsd:date')
        schema = [date_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Date]).to eq('invalid-date')
      end
    end

    context 'with empty values' do
      it 'returns empty string for empty elements' do
        xml = '<Response><Value></Value></Response>'
        value_element = schema_element('Value', type: 'xsd:string')
        schema = [value_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Value]).to eq('')
      end

      it 'returns empty string for empty integer elements (no type conversion)' do
        xml = '<Response><Count></Count></Response>'
        count_element = schema_element('Count', type: 'xsd:int')
        schema = [count_element]

        result = described_class.parse(xml, schema:)

        expect(result[:Response][:Count]).to eq('')
      end
    end
  end
end
