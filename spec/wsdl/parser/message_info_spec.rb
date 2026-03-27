# frozen_string_literal: true

RSpec.describe WSDL::Parser::MessageInfo do
  describe '#name' do
    it 'returns the message name attribute' do
      node = build_message_node('TestMessage', parts: [{ name: 'body', element: 'tns:Test' }])
      info = described_class.new(node)

      expect(info.name).to eq('TestMessage')
    end
  end

  describe '#parts' do
    it 'returns parts with element references' do
      node = build_message_node('ElementMsg', parts: [
        { name: 'parameters', element: 'tns:MyRequest' }
      ])

      info = described_class.new(node)
      parts = info.parts

      expect(parts.size).to eq(1)
      expect(parts.first[:name]).to eq('parameters')
      expect(parts.first[:element]).to eq('tns:MyRequest')
      expect(parts.first[:type]).to be_nil
    end

    it 'returns parts with type references' do
      node = build_message_node('TypeMsg', parts: [
        { name: 'value', type: 'xsd:string' }
      ])

      info = described_class.new(node)
      parts = info.parts

      expect(parts.size).to eq(1)
      expect(parts.first[:name]).to eq('value')
      expect(parts.first[:type]).to eq('xsd:string')
      expect(parts.first[:element]).to be_nil
    end

    it 'returns multiple parts' do
      node = build_message_node('MultiMsg', parts: [
        { name: 'sender', type: 'xsd:string' },
        { name: 'body', type: 'xsd:string' },
        { name: 'priority', type: 'xsd:int' }
      ])

      info = described_class.new(node)
      expect(info.parts.map { |p| p[:name] }).to eq(%w[sender body priority])
    end

    it 'returns an empty array when there are no parts' do
      node = build_message_node('EmptyMsg', parts: [])
      info = described_class.new(node)

      expect(info.parts).to eq([])
    end

    it 'includes namespace declarations from the message scope' do
      node = build_message_node('NsMsg', parts: [
        { name: 'a', element: 'tns:A' },
        { name: 'b', element: 'tns:B' }
      ])

      info = described_class.new(node)
      parts = info.parts

      parts.each do |part|
        expect(part[:namespaces]).to include('xmlns:tns' => 'urn:test')
        expect(part[:namespaces]).to include('xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema')
      end
    end

    it 'shares the same frozen namespace hash across all sibling parts' do
      node = build_message_node('SiblingMsg', parts: [
        { name: 'a', element: 'tns:A' },
        { name: 'b', element: 'tns:B' },
        { name: 'c', element: 'tns:C' }
      ])

      info = described_class.new(node)
      parts = info.parts

      # All sibling parts within the same message share one namespace hash object
      expect(parts[0][:namespaces]).to be(parts[1][:namespaces])
      expect(parts[1][:namespaces]).to be(parts[2][:namespaces])
      expect(parts[0][:namespaces]).to be_frozen
    end

    it 'skips non-part child elements' do
      xml = <<~XML
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:tns="urn:test"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="urn:test">
          <message name="MixedMsg">
            <part name="body" element="tns:Request"/>
            <documentation>This should be skipped</documentation>
          </message>
        </definitions>
      XML

      doc = Nokogiri::XML(xml)
      message_node = doc.at_xpath('//wsdl:message', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')
      info = described_class.new(message_node)

      expect(info.parts.size).to eq(1)
      expect(info.parts.first[:name]).to eq('body')
    end

    it 'memoizes the result' do
      node = build_message_node('MemoMsg', parts: [{ name: 'x', type: 'xsd:string' }])
      info = described_class.new(node)

      first_call = info.parts
      second_call = info.parts
      expect(first_call).to be(second_call)
    end
  end

  private

  def build_message_node(name, parts:)
    part_xml = parts.map { |p|
      attrs = "name=\"#{p[:name]}\""
      attrs += " type=\"#{p[:type]}\"" if p[:type]
      attrs += " element=\"#{p[:element]}\"" if p[:element]
      "<part #{attrs}/>"
    }.join("\n      ")

    xml = <<~XML
      <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                   xmlns:tns="urn:test"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   targetNamespace="urn:test">
        <message name="#{name}">
          #{part_xml}
        </message>
      </definitions>
    XML

    doc = Nokogiri::XML(xml)
    doc.at_xpath('//wsdl:message', 'wsdl' => 'http://schemas.xmlsoap.org/wsdl/')
  end
end
