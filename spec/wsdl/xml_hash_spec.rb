# frozen_string_literal: true

require 'spec_helper'

describe WSDL::XmlHash do
  describe '.parse' do
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
end
