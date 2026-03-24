# frozen_string_literal: true

# Tests verifying conformance to normative requirements from the
# W3C SOAP 1.1 specification (https://www.w3.org/TR/2000/NOTE-SOAP-20000508/).
#
# Each test references an assertion ID documented in W3C_CONFORMANCE_ASSERTIONS.md.

RSpec.describe 'SOAP 1.1 conformance' do
  let(:definition) { WSDL::Parser.parse fixture('wsdl/temperature'), http_mock }
  let(:op_data) { definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap', 'ConvertTemp') }
  let(:endpoint) { definition.endpoint('ConvertTemperature', 'ConvertTemperatureSoap') }
  let(:operation) { WSDL::Operation.new(op_data, endpoint, http_mock) }

  def parsed_envelope
    operation.prepare do
      body do
        tag('ConvertTemp') do
          tag('Temperature', 30)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    end

    Nokogiri::XML(operation.to_xml)
  end

  def build_response(xml)
    WSDL::Response.new(http_response: WSDL::HTTPResponse.new(status: 200, body: xml))
  end

  # --------------------------------------------------------------------------
  # Envelope Structure (Sender Rules)
  # --------------------------------------------------------------------------

  describe 'Envelope Structure' do
    let(:doc) { parsed_envelope }
    let(:root) { doc.root }

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383494
    it 'S11-ENV-1: Envelope element is present' do
      expect(root.name).to eq('Envelope')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383494
    it 'S11-ENV-2: Header is first immediate child of Envelope' do
      children = root.element_children
      expect(children.first.name).to eq('Header')
      expect(children[1].name).to eq('Body')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383494
    it 'S11-ENV-3: Body is present and an immediate child of Envelope' do
      body = root.element_children.find { |c| c.name == 'Body' }
      expect(body).not_to be_nil
      expect(body.parent).to eq(root)
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383496
    it 'S11-ENV-4: Envelope uses the SOAP 1.1 namespace' do
      expect(root.namespace.href).to eq('http://schemas.xmlsoap.org/soap/envelope/')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383492
    it 'S11-DTD-1: output does not contain a DOCTYPE' do
      expect(doc.to_xml).not_to match(/<!DOCTYPE/i)
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383492
    it 'S11-PI-1: output does not contain processing instructions' do
      expect(doc.to_xml).not_to match(/<\?(?!xml\b)/)
    end
  end

  # --------------------------------------------------------------------------
  # Fault Parsing (Receiver Rules)
  # --------------------------------------------------------------------------

  describe 'Fault Parsing' do
    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383507
    it 'S11-FLT-1: Fault inside Body is detected' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>Server error</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      response = build_response(xml)
      expect(response.fault?).to be true
      expect(response.fault.code).to eq('soap:Server')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383507
    it 'S11-FLT-2: faultcode is parsed as a QName string' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Client</faultcode>
              <faultstring>Bad request</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.code).to eq('soap:Client')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383507
    it 'S11-FLT-3: faultstring is parsed as reason' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>Something went wrong</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.reason).to eq('Something went wrong')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383507
    it 'S11-FLT-4: detail is parsed when present and nil when absent' do
      with_detail = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>Error</faultstring>
              <detail><Info>extra</Info></detail>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      without_detail = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>Error</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      expect(build_response(with_detail).fault.detail).to eq({ Info: 'extra' })
      expect(build_response(without_detail).fault.detail).to be_nil
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383507
    it 'S11-FLT-5: first Fault is used when multiple are present' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>First fault</faultstring>
            </soap:Fault>
            <soap:Fault>
              <faultcode>soap:Client</faultcode>
              <faultstring>Second fault</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.reason).to eq('First fault')
    end
  end

  # --------------------------------------------------------------------------
  # HTTP Binding
  # --------------------------------------------------------------------------

  describe 'HTTP Binding' do
    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383526
    it 'S11-HTTP-1: Content-Type is text/xml' do
      expect(operation.http_headers['Content-Type']).to start_with('text/xml')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383528
    it 'S11-HTTP-2: SOAPAction header is present' do
      expect(operation.http_headers).to have_key('SOAPAction')
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383528
    it 'S11-HTTP-3: SOAPAction is empty string when soap_action is nil' do
      operation.soap_action = nil
      expect(operation.http_headers['SOAPAction']).to eq('')
    end
  end

  # --------------------------------------------------------------------------
  # Namespace Handling (Receiver Rules)
  # --------------------------------------------------------------------------

  describe 'Namespace Handling' do
    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383492
    it 'S11-NS-1: responses with unusual SOAP prefixes are handled' do
      xml = <<-XML
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
          <soapenv:Body>
            <GetResponse><Value>42</Value></GetResponse>
          </soapenv:Body>
        </soapenv:Envelope>
      XML

      response = build_response(xml)
      expect(response.body).to include(GetResponse: { Value: '42' })
    end

    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383492
    it 'S11-NS-2: wrong envelope namespace produces empty body' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://example.com/wrong-namespace">
          <soap:Body>
            <GetResponse><Value>42</Value></GetResponse>
          </soap:Body>
        </soap:Envelope>
      XML

      response = build_response(xml)
      expect(response.body).to eq({})
    end
  end

  # --------------------------------------------------------------------------
  # Versioning
  # --------------------------------------------------------------------------

  describe 'Versioning' do
    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383496
    it 'S11-VER-1: wrong envelope namespace does not crash' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://example.com/not-soap">
          <soap:Body>
            <soap:Fault>
              <faultcode>soap:Server</faultcode>
              <faultstring>Error</faultstring>
            </soap:Fault>
          </soap:Body>
        </soap:Envelope>
      XML

      response = build_response(xml)
      expect { response.fault? }.not_to raise_error
      expect(response.fault).to be_nil
    end
  end

  # --------------------------------------------------------------------------
  # MustUnderstand (Design Choice Documentation)
  # --------------------------------------------------------------------------

  describe 'MustUnderstand' do
    # https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383500
    it 'S11-MU-1: unknown mustUnderstand="1" response headers are silently ignored' do
      xml = <<-XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Header>
            <CustomHeader xmlns="http://example.com/custom"
                          soap:mustUnderstand="1">
              important
            </CustomHeader>
          </soap:Header>
          <soap:Body>
            <GetResponse><Value>42</Value></GetResponse>
          </soap:Body>
        </soap:Envelope>
      XML

      response = build_response(xml)
      expect { response.body }.not_to raise_error
      expect(response.body).to include(GetResponse: { Value: '42' })
    end
  end
end
