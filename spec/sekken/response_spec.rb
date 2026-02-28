require 'spec_helper'

describe Sekken::Response do

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

  subject(:response) { Sekken::Response.new(soap_response) }

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
      expect(response.header).to eq({ session_id: 'abc123' })
    end
  end

  describe '#body' do
    it 'returns the parsed SOAP body' do
      expect(response.body).to eq({ response: { result: '42' } })
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