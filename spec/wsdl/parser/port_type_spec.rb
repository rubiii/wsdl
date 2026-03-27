# frozen_string_literal: true

RSpec.describe WSDL::Parser::PortType do
  describe '#name' do
    it 'returns the portType name attribute' do
      node = build_port_type_node('StockQuotePortType')
      port_type = described_class.new(node)

      expect(port_type.name).to eq('StockQuotePortType')
    end
  end

  describe '#operations' do
    it 'returns an OperationMap' do
      node = build_port_type_node('TestPortType', operations: [
        { name: 'GetPrice', input: 'tns:GetPriceRequest', output: 'tns:GetPriceResponse' }
      ])
      port_type = described_class.new(node)

      expect(port_type.operations).to be_a(WSDL::Parser::OperationMap)
    end

    it 'includes all operations by name' do
      node = build_port_type_node('TestPortType', operations: [
        { name: 'GetPrice', input: 'tns:GetPriceRequest', output: 'tns:GetPriceResponse' },
        { name: 'SetPrice', input: 'tns:SetPriceRequest', output: 'tns:SetPriceResponse' }
      ])
      port_type = described_class.new(node)

      expect(port_type.operations.keys).to contain_exactly('GetPrice', 'SetPrice')
    end

    it 'returns PortTypeOperation instances' do
      node = build_port_type_node('TestPortType', operations: [
        { name: 'GetPrice', input: 'tns:GetPriceRequest', output: 'tns:GetPriceResponse' }
      ])
      port_type = described_class.new(node)

      operation = port_type.operations.fetch('GetPrice')
      expect(operation).to be_a(WSDL::Parser::PortTypeOperation)
      expect(operation.input.message).to eq('tns:GetPriceRequest')
      expect(operation.output.message).to eq('tns:GetPriceResponse')
    end

    it 'skips non-operation child elements' do
      xml = <<~XML
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:tns="urn:test"
                     targetNamespace="urn:test">
          <portType name="TestPortType">
            <documentation>This should be skipped</documentation>
            <operation name="GetPrice">
              <input message="tns:GetPriceRequest"/>
              <output message="tns:GetPriceResponse"/>
            </operation>
          </portType>
        </definitions>
      XML

      doc = Nokogiri::XML(xml)
      node = doc.at_xpath('//wsdl:portType', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')
      port_type = described_class.new(node)

      expect(port_type.operations.keys).to eq(['GetPrice'])
    end

    it 'returns an empty OperationMap when there are no operations' do
      node = build_port_type_node('EmptyPortType', operations: [])
      port_type = described_class.new(node)

      expect(port_type.operations.keys).to eq([])
    end

    it 'memoizes the result' do
      node = build_port_type_node('TestPortType', operations: [
        { name: 'GetPrice', input: 'tns:GetPriceRequest', output: 'tns:GetPriceResponse' }
      ])
      port_type = described_class.new(node)

      first_call = port_type.operations
      second_call = port_type.operations
      expect(first_call).to be(second_call)
    end

    it 'shares the same frozen namespace hash across sibling operations' do
      node = build_port_type_node('TestPortType', operations: [
        { name: 'GetPrice', input: 'tns:GetPriceRequest', output: 'tns:GetPriceResponse' },
        { name: 'SetPrice', input: 'tns:SetPriceRequest', output: 'tns:SetPriceResponse' },
        { name: 'DeletePrice', input: 'tns:DeletePriceRequest', output: 'tns:DeletePriceResponse' }
      ])
      port_type = described_class.new(node)

      ops = port_type.operations
      get_op = ops.fetch('GetPrice')
      set_op = ops.fetch('SetPrice')
      delete_op = ops.fetch('DeletePrice')

      # All sibling operations share one frozen namespace hash object
      get_ns = get_op.send(:namespaces)
      set_ns = set_op.send(:namespaces)
      delete_ns = delete_op.send(:namespaces)

      expect(get_ns).to be(set_ns)
      expect(set_ns).to be(delete_ns)
      expect(get_ns).to be_frozen
    end
  end

  private

  def build_port_type_node(name, operations: [])
    ops_xml = operations.map { |op|
      children = []
      children << "<input message=\"#{op[:input]}\"/>" if op[:input]
      children << "<output message=\"#{op[:output]}\"/>" if op[:output]

      "<operation name=\"#{op[:name]}\">\n          #{children.join("\n          ")}\n        </operation>"
    }.join("\n        ")

    xml = <<~XML
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test">
        <portType name="#{name}">
          #{ops_xml}
        </portType>
      </definitions>
    XML

    doc = Nokogiri::XML(xml)
    doc.at_xpath(
      '//wsdl:portType',
      'wsdl' => 'http://schemas.xmlsoap.org/wsdl/'
    )
  end
end
