# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Response, type: :unit do
  include SchemaElementHelper

  let(:soap_response) do
    <<-XML
      <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header>
          <SessionId>abc123</SessionId>
        </env:Header>
        <env:Body>
          <Response>
            <Result>42</Result>
          </Response>
        </env:Body>
      </env:Envelope>
    XML
  end

  describe 'without output_parts (fallback to XmlHash)' do
    subject(:response) { described_class.new(soap_response) }

    describe '#raw' do
      it 'returns the raw XML response' do
        expect(response.raw).to eq(soap_response)
      end
    end

    describe '#doc' do
      it 'returns a Nokogiri XML document' do
        expect(response.doc).to be_a(Nokogiri::XML::Document)
      end

      it 'parses the raw response' do
        expect(response.doc.at_xpath('//Result').text).to eq('42')
      end
    end

    describe '#header' do
      it 'returns the parsed SOAP header' do
        expect(response.header).to eq({ SessionId: 'abc123' })
      end
    end

    describe '#body' do
      it 'returns the parsed SOAP body as strings' do
        expect(response.body).to eq({ Response: { Result: '42' } })
      end
    end

    describe '#hash' do
      it 'returns the complete parsed envelope' do
        expect(response.hash[:Envelope][:Body]).to eq({ Response: { Result: '42' } })
        expect(response.hash[:Envelope][:Header]).to eq({ SessionId: 'abc123' })
      end
    end

    describe '#xml_namespaces' do
      it 'returns a hash of namespaces from the document' do
        expect(response.xml_namespaces).to eq({
          'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/'
        })
      end
    end

    describe '#xpath' do
      it 'queries the document using the provided XPath expression' do
        result = response.xpath('//Result')
        expect(result.first.text).to eq('42')
      end

      it 'uses xml_namespaces by default for namespaced queries' do
        result = response.xpath('//env:Body')
        expect(result.size).to eq(1)
      end

      it 'accepts custom namespaces' do
        custom_ns = { 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/' }
        result = response.xpath('//soap:Body', custom_ns)
        expect(result.size).to eq(1)
      end

      it 'returns an empty NodeSet when no matches are found' do
        result = response.xpath('//NonExistent')
        expect(result).to be_empty
      end
    end
  end

  describe 'with output_parts (schema-aware parsing)' do
    describe '#body' do
      it 'converts integer types to Integer' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <Count>42</Count>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        count_element = schema_element('Count', type: 'xsd:int')
        response_element = schema_element('Response', children: [count_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.body[:Response][:Count]).to eq(42)
        expect(response.body[:Response][:Count]).to be_a(Integer)
      end

      it 'converts decimal types to BigDecimal' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <Price>99.99</Price>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        price_element = schema_element('Price', type: 'xsd:decimal')
        response_element = schema_element('Response', children: [price_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.body[:Response][:Price]).to eq(BigDecimal('99.99'))
        expect(response.body[:Response][:Price]).to be_a(BigDecimal)
      end

      it 'converts boolean types to true/false' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <Active>true</Active>
                <Deleted>false</Deleted>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        active_element = schema_element('Active', type: 'xsd:boolean')
        deleted_element = schema_element('Deleted', type: 'xsd:boolean')
        response_element = schema_element('Response', children: [active_element, deleted_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.body[:Response][:Active]).to be true
        expect(response.body[:Response][:Deleted]).to be false
      end

      it 'converts date types to Date' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <BirthDate>2024-01-15</BirthDate>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        date_element = schema_element('BirthDate', type: 'xsd:date')
        response_element = schema_element('Response', children: [date_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.body[:Response][:BirthDate]).to eq(Date.new(2024, 1, 15))
        expect(response.body[:Response][:BirthDate]).to be_a(Date)
      end

      it 'converts dateTime types to Time' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <CreatedAt>2024-01-15T10:30:00Z</CreatedAt>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        datetime_element = schema_element('CreatedAt', type: 'xsd:dateTime')
        response_element = schema_element('Response', children: [datetime_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.body[:Response][:CreatedAt]).to be_a(Time)
        expect(response.body[:Response][:CreatedAt].year).to eq(2024)
      end

      context 'array handling based on maxOccurs' do
        it 'returns array when schema says singular: false, even with single element' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <Item>only-one</Item>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          item_element = schema_element('Item', type: 'xsd:string', singular: false)
          response_element = schema_element('Response', children: [item_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:Item]).to eq(['only-one'])
          expect(response.body[:Response][:Item]).to be_an(Array)
        end

        it 'returns single value when schema says singular: true' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <Item>only-one</Item>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          item_element = schema_element('Item', type: 'xsd:string', singular: true)
          response_element = schema_element('Response', children: [item_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:Item]).to eq('only-one')
          expect(response.body[:Response][:Item]).not_to be_an(Array)
        end

        it 'returns array with multiple elements when singular: false' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <Item>one</Item>
                  <Item>two</Item>
                  <Item>three</Item>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          item_element = schema_element('Item', type: 'xsd:string', singular: false)
          response_element = schema_element('Response', children: [item_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:Item]).to eq(%w[one two three])
        end

        it 'returns array of complex types with proper conversion' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <User>
                    <Name>Alice</Name>
                    <Age>30</Age>
                  </User>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          name_element = schema_element('Name', type: 'xsd:string')
          age_element = schema_element('Age', type: 'xsd:int')
          user_element = schema_element('User', children: [name_element, age_element], singular: false)
          response_element = schema_element('Response', children: [user_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:User]).to eq([{ Name: 'Alice', Age: 30 }])
          expect(response.body[:Response][:User].first[:Age]).to be_a(Integer)
        end
      end

      context 'with xsi:nil' do
        it 'returns nil for element with xsi:nil="true"' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <Value xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:nil="true"/>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          value_element = schema_element('Value', type: 'xsd:string', nillable: true)
          response_element = schema_element('Response', children: [value_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:Value]).to be_nil
        end
      end

      context 'with unknown elements not in schema' do
        it 'includes unknown elements as strings' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>
                  <Known>expected</Known>
                  <Unknown>extra</Unknown>
                </Response>
              </env:Body>
            </env:Envelope>
          XML

          known_element = schema_element('Known', type: 'xsd:string')
          response_element = schema_element('Response', children: [known_element])
          output_parts = [response_element]

          response = described_class.new(xml, output_parts: output_parts)

          expect(response.body[:Response][:Known]).to eq('expected')
          expect(response.body[:Response][:Unknown]).to eq('extra')
        end
      end
    end

    describe '#header' do
      it 'still returns the parsed SOAP header using XmlHash' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
              <SessionId>abc123</SessionId>
            </env:Header>
            <env:Body>
              <Response>
                <Result>42</Result>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        result_element = schema_element('Result', type: 'xsd:int')
        response_element = schema_element('Response', children: [result_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        expect(response.header).to eq({ SessionId: 'abc123' })
      end
    end

    describe '#hash' do
      it 'returns the raw hash without schema-aware parsing' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <Count>42</Count>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        count_element = schema_element('Count', type: 'xsd:int')
        response_element = schema_element('Response', children: [count_element])
        output_parts = [response_element]

        response = described_class.new(xml, output_parts: output_parts)

        # hash method does NOT use schema-aware parsing
        expect(response.hash[:Envelope][:Body][:Response][:Count]).to eq('42')
      end
    end
  end

  describe 'real-world scenario' do
    it 'parses an order response with full type conversion' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
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
          </soap:Body>
        </soap:Envelope>
      XML

      # Build schema
      id_element = schema_element('Id', type: 'xsd:int')
      order_date_element = schema_element('OrderDate', type: 'xsd:date')
      shipped_element = schema_element('Shipped', type: 'xsd:boolean')
      total_element = schema_element('Total', type: 'xsd:decimal')

      name_element = schema_element('Name', type: 'xsd:string')
      price_element = schema_element('Price', type: 'xsd:decimal')
      quantity_element = schema_element('Quantity', type: 'xsd:int')

      item_element = schema_element('Item', children: [name_element, price_element, quantity_element], singular: false)
      items_element = schema_element('Items', children: [item_element])

      order_element = schema_element('Order', children: [
        id_element, order_date_element, shipped_element, total_element, items_element
      ])

      response_element = schema_element('GetOrderResponse', children: [order_element])
      output_parts = [response_element]

      response = described_class.new(xml, output_parts: output_parts)

      expect(response.body).to eq({
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
