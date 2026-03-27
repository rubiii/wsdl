# frozen_string_literal: true

RSpec.describe WSDL::Parser::MessageReference do
  describe '.from_node' do
    it 'resolves a prefixed message attribute into a QName' do
      node = build_io_node(message: 'tns:TestInput')
      ref = described_class.from_node(node)

      expect(ref.name).to be_nil
      expect(ref.message).to eq('tns:TestInput')
      expect(ref.message_name).to be_a(WSDL::QName)
      expect(ref.message_name.namespace).to eq('urn:test')
      expect(ref.message_name.local).to eq('TestInput')
    end

    it 'preserves the name attribute from the node' do
      node = build_io_node(name: 'myInput', message: 'tns:TestInput')
      ref = described_class.from_node(node)

      expect(ref.name).to eq('myInput')
    end

    it 'sets message_name to nil when message attribute is absent' do
      node = build_io_node(message: nil)
      ref = described_class.from_node(node)

      expect(ref.message).to be_nil
      expect(ref.message_name).to be_nil
    end

    it 'resolves using the document targetNamespace as default namespace' do
      node = build_io_node(message: 'tns:GetPrice', target_namespace: 'urn:prices')
      ref = described_class.from_node(node)

      expect(ref.message_name.namespace).to eq('urn:prices')
      expect(ref.message_name.local).to eq('GetPrice')
    end

    it 'uses namespace declarations from the node scope' do
      node = build_io_node(
        message: 'ext:ExternalMsg',
        extra_namespaces: { 'xmlns:ext' => 'urn:external-service' }
      )
      ref = described_class.from_node(node)

      expect(ref.message_name.namespace).to eq('urn:external-service')
      expect(ref.message_name.local).to eq('ExternalMsg')
    end

    it 'uses a pre-resolved namespaces hash when provided' do
      node = build_io_node(message: 'custom:Msg')
      namespaces = { 'xmlns:custom' => 'urn:custom-ns' }

      ref = described_class.from_node(node, namespaces:)

      expect(ref.message_name.namespace).to eq('urn:custom-ns')
      expect(ref.message_name.local).to eq('Msg')
    end

    it 'returns identical namespace resolution for sibling nodes' do
      doc = build_operation_doc(
        input_message: 'tns:RequestMsg',
        output_message: 'tns:ResponseMsg'
      )

      input_node = doc.at_xpath('//wsdl:input', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')
      output_node = doc.at_xpath('//wsdl:output', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')

      input_ref = described_class.from_node(input_node)
      output_ref = described_class.from_node(output_node)

      # Both resolve against the same namespace scope
      expect(input_ref.message_name.namespace).to eq('urn:test')
      expect(output_ref.message_name.namespace).to eq('urn:test')
    end
  end

  private

  def build_io_node(message: 'tns:TestInput', name: nil, target_namespace: 'urn:test', extra_namespaces: {})
    ns_attrs = extra_namespaces.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')
    name_attr = name ? "name=\"#{name}\"" : ''
    message_attr = message ? "message=\"#{message}\"" : ''

    xml = <<~XML
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:tns="#{target_namespace}"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   #{ns_attrs}
                   targetNamespace="#{target_namespace}">
        <portType name="TestPortType">
          <operation name="TestOp">
            <input #{name_attr} #{message_attr}/>
          </operation>
        </portType>
      </definitions>
    XML

    doc = Nokogiri::XML(xml)
    doc.at_xpath('//wsdl:input', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')
  end

  def build_operation_doc(input_message:, output_message:)
    xml = <<~XML
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test">
        <portType name="TestPortType">
          <operation name="TestOp">
            <input message="#{input_message}"/>
            <output message="#{output_message}"/>
          </operation>
        </portType>
      </definitions>
    XML

    Nokogiri::XML(xml)
  end
end
