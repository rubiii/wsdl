# frozen_string_literal: true

# Tests verifying conformance to normative requirements from the
# W3C SOAP 1.2 Part 1 (https://www.w3.org/TR/soap12-part1/) and
# Part 2 (https://www.w3.org/TR/soap12-part2/) specifications.
#
# Each test references an assertion ID documented in W3C_CONFORMANCE_ASSERTIONS.md.

RSpec.describe 'SOAP 1.2 conformance' do
  let(:definition) { WSDL::Parser.parse fixture('wsdl/temperature'), http_mock }

  let(:soap12_data) { definition.operation_data('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }
  let(:soap12_endpoint) { definition.endpoint('ConvertTemperature', 'ConvertTemperatureSoap12') }
  let(:soap12_operation) { WSDL::Operation.new(soap12_data, soap12_endpoint, http_mock) }

  let(:rpc_definition) { WSDL::Parser.parse fixture('wsdl/rpc_literal'), http_mock }
  let(:rpc_data) { rpc_definition.operation_data('SampleService', 'Sample', 'op1') }
  let(:rpc_endpoint) { rpc_definition.endpoint('SampleService', 'Sample') }
  let(:rpc_operation) { WSDL::Operation.new(rpc_data, rpc_endpoint, http_mock) }

  def parsed_soap12_envelope
    soap12_operation.prepare do
      body do
        tag('ConvertTemp') do
          tag('Temperature', 30)
          tag('FromUnit', 'degreeCelsius')
          tag('ToUnit', 'degreeFahrenheit')
        end
      end
    end

    Nokogiri::XML(soap12_operation.to_xml)
  end

  def build_response(xml, status: 200)
    WSDL::Response.new(http_response: WSDL::HTTP::Response.new(status:, body: xml))
  end

  # --------------------------------------------------------------------------
  # Envelope Structure (Sender Rules)
  # --------------------------------------------------------------------------

  describe 'Envelope Structure' do
    let(:doc) { parsed_soap12_envelope }
    let(:root) { doc.root }

    # https://www.w3.org/TR/soap12-part1/#soapenv
    it 'S12-ENV-1: Envelope element is present' do
      expect(root.name).to eq('Envelope')
    end

    # https://www.w3.org/TR/soap12-part1/#soapenv
    it 'S12-ENV-2: output does not contain a DOCTYPE' do
      expect(doc.to_xml).not_to match(/<!DOCTYPE/i)
    end

    # https://www.w3.org/TR/soap12-part1/#soapenv
    it 'S12-ENV-3: output does not contain processing instructions' do
      expect(doc.to_xml).not_to match(/<\?(?!xml\b)/)
    end

    # https://www.w3.org/TR/soap12-part1/#soapenvelope
    it 'S12-ENV-4: Envelope uses the SOAP 1.2 namespace' do
      expect(root.namespace.href).to eq('http://www.w3.org/2003/05/soap-envelope')
    end

    # https://www.w3.org/TR/soap12-part1/#soaphead
    it 'S12-ENV-5: Header is in the SOAP 1.2 namespace' do
      header = root.element_children.first
      expect(header.name).to eq('Header')
      expect(header.namespace.href).to eq('http://www.w3.org/2003/05/soap-envelope')
    end

    # https://www.w3.org/TR/soap12-part1/#soapbody
    it 'S12-ENV-6: Body is in the SOAP 1.2 namespace' do
      body = root.element_children.find { |c| c.name == 'Body' }
      expect(body).not_to be_nil
      expect(body.namespace.href).to eq('http://www.w3.org/2003/05/soap-envelope')
    end
  end

  # --------------------------------------------------------------------------
  # Fault Parsing (Receiver Rules)
  # --------------------------------------------------------------------------

  describe 'Fault Parsing' do
    # https://www.w3.org/TR/soap12-part1/#soapfault
    it 'S12-FLT-1: Fault with all five children is parsed' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Server error</env:Text></env:Reason>
              <env:Node>http://example.com/node</env:Node>
              <env:Role>http://example.com/role</env:Role>
              <env:Detail><Info>details</Info></env:Detail>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.code).to eq('env:Receiver')
      expect(fault.reason).to eq('Server error')
      expect(fault.node).to eq('http://example.com/node')
      expect(fault.role).to eq('http://example.com/role')
      expect(fault.detail).to eq({ Info: 'details' })
    end

    # https://www.w3.org/TR/soap12-part1/#soapfault
    it 'S12-FLT-2: Fault is found even with sibling Body children' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Sender</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Bad</env:Text></env:Reason>
            </env:Fault>
            <Extra>should not be here per spec</Extra>
          </env:Body>
        </env:Envelope>
      XML

      response = build_response(xml)
      expect(response.fault?).to be true
      expect(response.fault.code).to eq('env:Sender')
    end

    # https://www.w3.org/TR/soap12-part1/#faultcodeelement
    it 'S12-FLT-3: Code/Value is parsed' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Sender</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Error</env:Text></env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.code).to eq('env:Sender')
    end

    # https://www.w3.org/TR/soap12-part1/#faultsubcodeelement
    it 'S12-FLT-4: nested Subcodes are collected in order' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code>
                <env:Value>env:Sender</env:Value>
                <env:Subcode>
                  <env:Value>app:ValidationError</env:Value>
                  <env:Subcode>
                    <env:Value>app:MissingField</env:Value>
                    <env:Subcode>
                      <env:Value>app:RequiredName</env:Value>
                    </env:Subcode>
                  </env:Subcode>
                </env:Subcode>
              </env:Code>
              <env:Reason><env:Text xml:lang="en">Validation failed</env:Text></env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.code).to eq('env:Sender')
      expect(fault.subcodes).to eq(%w[app:ValidationError app:MissingField app:RequiredName])
    end

    # https://www.w3.org/TR/soap12-part1/#faultstringelement
    it 'S12-FLT-5: first Reason/Text is used when multiple languages present' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason>
                <env:Text xml:lang="en">English error</env:Text>
                <env:Text xml:lang="de">Deutscher Fehler</env:Text>
              </env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.reason).to eq('English error')
    end

    # https://www.w3.org/TR/soap12-part1/#reasontextelement
    it 'S12-FLT-6: Text is extracted regardless of xml:lang value' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason>
                <env:Text xml:lang="ja">サーバーエラー</env:Text>
              </env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.reason).to eq('サーバーエラー')
    end

    # https://www.w3.org/TR/soap12-part1/#faultactorelement
    it 'S12-FLT-7: Node URI is parsed' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Error</env:Text></env:Reason>
              <env:Node>http://example.com/services/stock</env:Node>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.node).to eq('http://example.com/services/stock')
    end

    # https://www.w3.org/TR/soap12-part1/#faultroleelement
    it 'S12-FLT-8: Role is parsed' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Error</env:Text></env:Reason>
              <env:Role>http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver</env:Role>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.role).to eq(
        'http://www.w3.org/2003/05/soap-envelope/role/ultimateReceiver'
      )
    end

    # https://www.w3.org/TR/soap12-part1/#faultdetailelement
    it 'S12-FLT-9: Detail is parsed into a hash' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Error</env:Text></env:Reason>
              <env:Detail>
                <ErrorInfo><Severity>critical</Severity><Module>auth</Module></ErrorInfo>
              </env:Detail>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      expect(build_response(xml).fault.detail).to eq(
        { ErrorInfo: { Severity: 'critical', Module: 'auth' } }
      )
    end
  end

  # --------------------------------------------------------------------------
  # Versioning
  # --------------------------------------------------------------------------

  describe 'Versioning' do
    # https://www.w3.org/TR/soap12-part1/#envvermodel
    it 'S12-VER-1: VersionMismatch fault is parsed correctly' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:VersionMismatch</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Wrong version</env:Text></env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.code).to eq('env:VersionMismatch')
      expect(fault.reason).to eq('Wrong version')
    end

    # https://www.w3.org/TR/soap12-part1/#envvermodel
    it 'S12-VER-2: SOAP 1.2 response parsed correctly regardless of operation SOAP version' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Sender</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Invalid</env:Text></env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      response = build_response(xml)
      fault = response.fault
      expect(fault).not_to be_nil
      expect(fault.code).to eq('env:Sender')
      expect(fault.subcodes).to eq([])
    end

    # https://www.w3.org/TR/soap12-part1/#soapupgrade
    it 'S12-VER-3: Upgrade header is accessible in VersionMismatch response' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Header>
            <env:Upgrade>
              <env:SupportedEnvelope qname="ns1:Envelope"
                                     xmlns:ns1="http://www.w3.org/2003/05/soap-envelope"/>
            </env:Upgrade>
          </env:Header>
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:VersionMismatch</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">Version not supported</env:Text></env:Reason>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      response = build_response(xml)
      expect(response.fault.code).to eq('env:VersionMismatch')

      upgrade = response.doc.xpath('//env:Upgrade', 'env' => 'http://www.w3.org/2003/05/soap-envelope')
      expect(upgrade).not_to be_empty
    end
  end

  # --------------------------------------------------------------------------
  # HTTP Binding
  # --------------------------------------------------------------------------

  describe 'HTTP Binding' do
    # https://www.w3.org/TR/soap12-part2/#httpmediatype
    it 'S12-HTTP-1: Content-Type is application/soap+xml' do
      expect(soap12_operation.http_headers['Content-Type']).to start_with('application/soap+xml')
    end

    # https://www.w3.org/TR/soap12-part2/#httpmediatype
    it 'S12-HTTP-2: action parameter is present in Content-Type when soap_action is set' do
      content_type = soap12_operation.http_headers['Content-Type']
      expect(content_type).to include('action=')
    end

    it 'S12-HTTP-2b: action parameter is absent when soap_action is nil' do
      soap12_operation.soap_action = nil
      content_type = soap12_operation.http_headers['Content-Type']
      expect(content_type).not_to include('action=')
    end
  end

  # --------------------------------------------------------------------------
  # MustUnderstand
  # --------------------------------------------------------------------------

  describe 'MustUnderstand' do
    # https://www.w3.org/TR/soap12-part1/#soapmu
    it 'S12-MU-1: WS-Security header uses mustUnderstand="true" for SOAP 1.2' do
      soap12_operation.prepare do
        ws_security do
          timestamp
        end

        body do
          tag('ConvertTemp') do
            tag('Temperature', 30)
            tag('FromUnit', 'degreeCelsius')
            tag('ToUnit', 'degreeFahrenheit')
          end
        end
      end

      xml = soap12_operation.to_xml
      expect(xml).to include('mustUnderstand="true"')
      expect(xml).not_to include('mustUnderstand="1"')
    end
  end

  # --------------------------------------------------------------------------
  # RPC Convention (Part 2)
  # --------------------------------------------------------------------------

  describe 'RPC Convention' do
    # https://www.w3.org/TR/soap12-part2/#rpcencrestriction
    it 'S12P2-RPC-1: RPC Body has a single child element after wrapping' do
      rpc_operation.soap_version = '1.2'

      rpc_operation.prepare do
        body do
          tag('in') do
            tag('data1', 24)
            tag('data2', 36)
          end
        end
      end

      doc = Nokogiri::XML(rpc_operation.to_xml)
      expect(doc.root.namespace.href).to eq('http://www.w3.org/2003/05/soap-envelope')

      body = doc.root.element_children.find { |c| c.name == 'Body' }
      expect(body.element_children.size).to eq(1)
      expect(body.element_children.first.name).to eq('op1')
    end

    # https://www.w3.org/TR/soap12-part2/#rpcresponse
    it 'S12P2-RPC-2: RPC response wrapper is traversed during parsing' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <ns0:op1Response xmlns:ns0="http://apiNamespace.com">
              <op1Return><data1>10</data1><data2>20</data2></op1Return>
            </ns0:op1Response>
          </env:Body>
        </env:Envelope>
      XML

      response = build_response(xml)
      body = response.body
      expect(body).to have_key(:op1Response)
      expect(body[:op1Response]).to have_key(:op1Return)
    end

    # https://www.w3.org/TR/soap12-part2/#rpcfaults
    it 'S12P2-RPC-3: RPC fault is parsed as a structured SOAP 1.2 fault' do
      xml = <<-XML
        <env:Envelope xmlns:env="http://www.w3.org/2003/05/soap-envelope">
          <env:Body>
            <env:Fault>
              <env:Code><env:Value>env:Receiver</env:Value></env:Code>
              <env:Reason><env:Text xml:lang="en">RPC method failed</env:Text></env:Reason>
              <env:Detail><MethodFault>op1 error</MethodFault></env:Detail>
            </env:Fault>
          </env:Body>
        </env:Envelope>
      XML

      fault = build_response(xml).fault
      expect(fault.code).to eq('env:Receiver')
      expect(fault.reason).to eq('RPC method failed')
      expect(fault.detail).to eq({ MethodFault: 'op1 error' })
    end
  end
end
