# frozen_string_literal: true

require 'spec_helper'
require_relative 'security/verifier/shared_context'

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

  describe '#http_status' do
    it 'returns nil when no HTTP response is provided' do
      response = described_class.new(soap_response)

      expect(response.http_status).to be_nil
    end

    it 'returns the HTTP status code from the HTTP response' do
      http = WSDL::HTTPResponse.new(status: 500, body: soap_response)
      response = described_class.new(http:)

      expect(response.http_status).to eq(500)
    end
  end

  describe '#http_headers' do
    it 'returns an empty hash when no HTTP response is provided' do
      response = described_class.new(soap_response)

      expect(response.http_headers).to eq({})
    end

    it 'returns the HTTP headers from the HTTP response' do
      headers = { 'Content-Type' => 'text/xml' }
      http = WSDL::HTTPResponse.new(status: 200, headers:, body: soap_response)
      response = described_class.new(http:)

      expect(response.http_headers).to eq(headers)
    end
  end

  describe 'without schema parts (fallback to parser)' do
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

    describe '#envelope_hash' do
      it 'returns the complete parsed envelope' do
        expect(response.envelope_hash[:Envelope][:Body]).to eq({ Response: { Result: '42' } })
        expect(response.envelope_hash[:Envelope][:Header]).to eq({ SessionId: 'abc123' })
      end
    end

    describe '#to_envelope_hash' do
      it 'aliases #envelope_hash' do
        expect(response.to_envelope_hash).to eq(response.envelope_hash)
      end
    end

    describe '#hash' do
      it 'returns an Integer and works as a Hash key' do
        expect(response.hash).to be_a(Integer)

        values = { response => :ok }
        expect(values[response]).to eq(:ok)
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

  describe '#security', :verifier_helpers do
    subject(:response) { described_class.new(pretty_signed_response) }

    let(:pretty_signed_response) { Nokogiri::XML(signed_soap_response).to_xml(indent: 2) }

    it 'verifies pretty-printed signed responses' do
      expect(response.security.signature_valid?).to be true
    end
  end

  describe 'with output_body_parts (schema-aware body parsing)' do
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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

        expect(response.body[:Response][:CreatedAt]).to be_a(Time)
        expect(response.body[:Response][:CreatedAt].year).to eq(2024)
      end

      it 'keeps dateTime values without explicit timezone as strings' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <Response>
                <CreatedAt>2024-01-15T10:30:00</CreatedAt>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        datetime_element = schema_element('CreatedAt', type: 'xsd:dateTime')
        response_element = schema_element('Response', children: [datetime_element])
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

        expect(response.body[:Response][:CreatedAt]).to eq('2024-01-15T10:30:00')
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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

          expect(response.body[:Response][:Known]).to eq('expected')
          expect(response.body[:Response][:Unknown]).to eq('extra')
        end

        it 'keeps text content for complex schema elements without child schema' do
          xml = <<-XML
            <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
              <env:Body>
                <Response>raw-content</Response>
              </env:Body>
            </env:Envelope>
          XML
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
          output_body_parts = [response_element]

          response = described_class.new(xml, output_body_parts:)

          expect(response.body).to eq({ Response: 'raw-content' })
        end
      end
    end

    describe '#header' do
      it 'returns the parsed SOAP header without type conversion when no header parts provided' do
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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

        expect(response.header).to eq({ SessionId: 'abc123' })
      end
    end

    describe '#envelope_hash' do
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
        output_body_parts = [response_element]

        response = described_class.new(xml, output_body_parts:)

        # envelope_hash does NOT use schema-aware parsing
        expect(response.envelope_hash[:Envelope][:Body][:Response][:Count]).to eq('42')
      end
    end
  end

  describe 'with output_header_parts (schema-aware header parsing)' do
    describe '#header' do
      it 'converts header values using schema types' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
              <RequestId>12345</RequestId>
              <Timestamp>2024-01-15T10:30:00Z</Timestamp>
            </env:Header>
            <env:Body>
              <Response>
                <Result>OK</Result>
              </Response>
            </env:Body>
          </env:Envelope>
        XML

        request_id_element = schema_element('RequestId', type: 'xsd:int')
        timestamp_element = schema_element('Timestamp', type: 'xsd:dateTime')
        output_header_parts = [request_id_element, timestamp_element]

        response = described_class.new(xml, output_header_parts:)

        expect(response.header[:RequestId]).to eq(12_345)
        expect(response.header[:RequestId]).to be_a(Integer)
        expect(response.header[:Timestamp]).to be_a(Time)
        expect(response.header[:Timestamp].year).to eq(2024)
      end

      it 'handles arrays in headers based on maxOccurs' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
              <Token>token1</Token>
              <Token>token2</Token>
            </env:Header>
            <env:Body>
              <Response><Result>OK</Result></Response>
            </env:Body>
          </env:Envelope>
        XML

        token_element = schema_element('Token', type: 'xsd:string', singular: false)
        output_header_parts = [token_element]

        response = described_class.new(xml, output_header_parts:)

        expect(response.header[:Token]).to eq(%w[token1 token2])
      end

      it 'handles complex header elements' do
        xml = <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Header>
              <AuthHeader>
                <UserId>user123</UserId>
                <Expires>300</Expires>
              </AuthHeader>
            </env:Header>
            <env:Body>
              <Response><Result>OK</Result></Response>
            </env:Body>
          </env:Envelope>
        XML

        user_id_element = schema_element('UserId', type: 'xsd:string')
        expires_element = schema_element('Expires', type: 'xsd:int')
        auth_header_element = schema_element('AuthHeader', children: [user_id_element, expires_element])
        output_header_parts = [auth_header_element]

        response = described_class.new(xml, output_header_parts:)

        expect(response.header[:AuthHeader]).to eq({ UserId: 'user123', Expires: 300 })
        expect(response.header[:AuthHeader][:Expires]).to be_a(Integer)
      end
    end
  end

  describe 'with both body and header parts' do
    it 'applies schema-aware parsing to both body and header' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          <env:Header>
            <SessionExpiry>3600</SessionExpiry>
          </env:Header>
          <env:Body>
            <Response>
              <Count>42</Count>
            </Response>
          </env:Body>
        </env:Envelope>
      XML

      # Body schema
      count_element = schema_element('Count', type: 'xsd:int')
      response_element = schema_element('Response', children: [count_element])
      output_body_parts = [response_element]

      # Header schema
      expiry_element = schema_element('SessionExpiry', type: 'xsd:int')
      output_header_parts = [expiry_element]

      response = described_class.new(xml, output_body_parts:, output_header_parts:)

      expect(response.body[:Response][:Count]).to eq(42)
      expect(response.body[:Response][:Count]).to be_a(Integer)
      expect(response.header[:SessionExpiry]).to eq(3600)
      expect(response.header[:SessionExpiry]).to be_a(Integer)
    end
  end

  describe '#fault? and #fault' do
    context 'with a SOAP 1.1 fault' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
            <env:Body>
              <env:Fault>
                <faultcode>env:Server</faultcode>
                <faultstring>Something went wrong</faultstring>
                <faultactor>http://example.com/actor</faultactor>
                <detail>
                  <Error>
                    <Code>500</Code>
                    <Message>Internal error</Message>
                  </Error>
                </detail>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'detects the fault' do
        expect(response.fault?).to be true
      end

      it 'returns a Fault object' do
        expect(response.fault).to be_a(WSDL::Response::Fault)
      end

      it 'parses the fault code' do
        expect(response.fault.code).to eq('env:Server')
      end

      it 'returns empty subcodes for SOAP 1.1' do
        expect(response.fault.subcodes).to eq([])
      end

      it 'parses the fault string' do
        expect(response.fault.reason).to eq('Something went wrong')
      end

      it 'parses the fault actor as role' do
        expect(response.fault.role).to eq('http://example.com/actor')
      end

      it 'returns nil for node in SOAP 1.1' do
        expect(response.fault.node).to be_nil
      end

      it 'parses the fault detail' do
        expect(response.fault.detail).to eq({ Error: { Code: '500', Message: 'Internal error' } })
      end

      it 'provides a human-readable string' do
        expect(response.fault.to_s).to eq('(env:Server) Something went wrong [role: http://example.com/actor]')
      end
    end

    context 'with a SOAP 1.1 fault without optional elements' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <soap:Fault>
                <faultcode>soap:Client</faultcode>
                <faultstring>Invalid request</faultstring>
              </soap:Fault>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'detects the fault' do
        expect(response.fault?).to be true
      end

      it 'returns nil for missing role' do
        expect(response.fault.role).to be_nil
      end

      it 'returns nil for missing detail' do
        expect(response.fault.detail).to be_nil
      end

      it 'provides a string without role' do
        expect(response.fault.to_s).to eq('(soap:Client) Invalid request')
      end
    end

    context 'with a SOAP 1.1 fault with empty detail element' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <soap:Fault>
                <faultcode>soap:Server</faultcode>
                <faultstring>Error</faultstring>
                <detail/>
              </soap:Fault>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns nil for empty detail' do
        expect(response.fault.detail).to be_nil
      end
    end

    context 'with a SOAP 1.2 fault' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Body>
              <env:Fault>
                <env:Code>
                  <env:Value>env:Receiver</env:Value>
                </env:Code>
                <env:Reason>
                  <env:Text xml:lang="en">Processing failed</env:Text>
                </env:Reason>
                <env:Node>http://example.com/node</env:Node>
                <env:Role>http://example.com/role</env:Role>
                <env:Detail>
                  <ErrorInfo>
                    <Severity>critical</Severity>
                  </ErrorInfo>
                </env:Detail>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'detects the fault' do
        expect(response.fault?).to be true
      end

      it 'parses the fault code' do
        expect(response.fault.code).to eq('env:Receiver')
      end

      it 'returns empty subcodes when none present' do
        expect(response.fault.subcodes).to eq([])
      end

      it 'parses the fault reason' do
        expect(response.fault.reason).to eq('Processing failed')
      end

      it 'parses the node' do
        expect(response.fault.node).to eq('http://example.com/node')
      end

      it 'parses the role' do
        expect(response.fault.role).to eq('http://example.com/role')
      end

      it 'parses the detail' do
        expect(response.fault.detail).to eq({ ErrorInfo: { Severity: 'critical' } })
      end
    end

    context 'with a SOAP 1.2 fault with subcodes' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Body>
              <env:Fault>
                <env:Code>
                  <env:Value>env:Sender</env:Value>
                  <env:Subcode>
                    <env:Value>app:ValidationError</env:Value>
                    <env:Subcode>
                      <env:Value>app:MissingField</env:Value>
                    </env:Subcode>
                  </env:Subcode>
                </env:Code>
                <env:Reason>
                  <env:Text xml:lang="en">Validation failed</env:Text>
                </env:Reason>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'parses the top-level code' do
        expect(response.fault.code).to eq('env:Sender')
      end

      it 'collects nested subcodes in order' do
        expect(response.fault.subcodes).to eq(%w[app:ValidationError app:MissingField])
      end
    end

    context 'with a SOAP 1.2 fault without optional elements' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Body>
              <env:Fault>
                <env:Code>
                  <env:Value>env:Sender</env:Value>
                </env:Code>
                <env:Reason>
                  <env:Text xml:lang="en">Bad request</env:Text>
                </env:Reason>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'returns nil for missing role' do
        expect(response.fault.role).to be_nil
      end

      it 'returns nil for missing node' do
        expect(response.fault.node).to be_nil
      end

      it 'returns nil for missing detail' do
        expect(response.fault.detail).to be_nil
      end
    end

    context 'with a SOAP 1.2 fault with empty Detail element' do
      subject(:response) { described_class.new(fault_xml) }

      let(:fault_xml) do
        <<-XML
          <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Body>
              <env:Fault>
                <env:Code>
                  <env:Value>env:Receiver</env:Value>
                </env:Code>
                <env:Reason>
                  <env:Text xml:lang="en">Error</env:Text>
                </env:Reason>
                <env:Detail/>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end

      it 'returns nil for empty detail' do
        expect(response.fault.detail).to be_nil
      end
    end

    context 'with a normal (non-fault) response' do
      subject(:response) { described_class.new(soap_response) }

      it 'returns false for fault?' do
        expect(response.fault?).to be false
      end

      it 'returns nil for fault' do
        expect(response.fault).to be_nil
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
      output_body_parts = [response_element]

      response = described_class.new(xml, output_body_parts:)

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
