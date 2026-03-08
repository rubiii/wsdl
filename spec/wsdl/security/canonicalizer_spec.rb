# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Canonicalizer do
  describe 'ALGORITHMS' do
    it 'includes exclusive_1_0 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:exclusive_1_0)
    end

    it 'includes exclusive_1_0_with_comments algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:exclusive_1_0_with_comments)
    end

    it 'includes inclusive_1_0 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:inclusive_1_0)
    end

    it 'includes inclusive_1_0_with_comments algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:inclusive_1_0_with_comments)
    end

    it 'includes inclusive_1_1 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:inclusive_1_1)
    end

    it 'includes inclusive_1_1_with_comments algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:inclusive_1_1_with_comments)
    end
  end

  describe 'DEFAULT_ALGORITHM' do
    it 'defaults to exclusive_1_0' do
      expect(described_class::DEFAULT_ALGORITHM).to eq(:exclusive_1_0)
    end
  end

  describe '#initialize' do
    context 'with default algorithm' do
      subject(:canonicalizer) { described_class.new }

      it 'uses exclusive_1_0 by default' do
        expect(canonicalizer.algorithm[:id]).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
      end
    end

    context 'with specified algorithm' do
      it 'accepts :exclusive_1_0' do
        canonicalizer = described_class.new(algorithm: :exclusive_1_0)
        expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
      end

      it 'accepts :inclusive_1_0' do
        canonicalizer = described_class.new(algorithm: :inclusive_1_0)
        expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/TR/2001/REC-xml-c14n-20010315')
      end

      it 'accepts :inclusive_1_1' do
        canonicalizer = described_class.new(algorithm: :inclusive_1_1)
        expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/2006/12/xml-c14n11')
      end
    end

    context 'with unknown algorithm' do
      it 'raises ArgumentError' do
        expect { described_class.new(algorithm: :unknown) }.to raise_error(
          ArgumentError, /Unknown canonicalization algorithm: :unknown/
        )
      end
    end
  end

  describe '#canonicalize' do
    subject(:canonicalizer) { described_class.new }

    context 'with simple XML' do
      let(:xml) { '<root><child>text</child></root>' }
      let(:doc) { Nokogiri::XML(xml) }

      it 'returns canonicalized XML string' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).to be_a(String)
      end

      it 'preserves element structure' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).to include('<root>')
        expect(result).to include('<child>text</child>')
        expect(result).to include('</root>')
      end
    end

    context 'with namespaced XML' do
      let(:xml) do
        <<~XML
          <root xmlns="http://example.com/ns" xmlns:ex="http://example.com/ex">
            <child>text</child>
            <ex:other>more</ex:other>
          </root>
        XML
      end
      let(:doc) { Nokogiri::XML(xml) }

      it 'handles namespaces correctly' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).to include('xmlns="http://example.com/ns"')
      end
    end

    context 'with attributes' do
      let(:xml) { '<root z="last" a="first"><child id="1"/></root>' }
      let(:doc) { Nokogiri::XML(xml) }

      it 'sorts attributes alphabetically' do
        result = canonicalizer.canonicalize(doc.root)
        # In canonical form, attributes are sorted by namespace URI then local name
        expect(result).to match(/a="first".*z="last"/)
      end
    end

    context 'with whitespace' do
      let(:xml) do
        <<~XML
          <root>
            <child>  text  </child>
          </root>
        XML
      end
      let(:doc) { Nokogiri::XML(xml) }

      it 'handles whitespace according to C14N rules' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).to be_a(String)
      end
    end

    context 'with inclusive namespaces' do
      let(:xml) do
        <<~XML
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <content>data</content>
            </soap:Body>
          </soap:Envelope>
        XML
      end
      let(:doc) { Nokogiri::XML(xml) }

      it 'accepts inclusive_namespaces parameter' do
        body = doc.at_xpath('//soap:Body', 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/')
        result = canonicalizer.canonicalize(body, inclusive_namespaces: ['soap'])
        expect(result).to be_a(String)
      end
    end

    context 'with comments using algorithm without comments' do
      subject(:canonicalizer) { described_class.new(algorithm: :exclusive_1_0) }

      let(:xml) { '<root><!-- comment --><child>text</child></root>' }
      let(:doc) { Nokogiri::XML(xml) }

      it 'removes comments' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).not_to include('comment')
      end
    end

    context 'with comments using algorithm with comments' do
      subject(:canonicalizer) { described_class.new(algorithm: :exclusive_1_0_with_comments) }

      let(:xml) { '<root><!-- comment --><child>text</child></root>' }
      let(:doc) { Nokogiri::XML(xml) }

      it 'preserves comments' do
        result = canonicalizer.canonicalize(doc.root)
        expect(result).to include('<!-- comment -->')
      end
    end
  end

  describe '#algorithm_id' do
    it 'returns correct URI for exclusive_1_0' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0)
      expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
    end

    it 'returns correct URI for exclusive_1_0_with_comments' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0_with_comments)
      expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/2001/10/xml-exc-c14n#WithComments')
    end

    it 'returns correct URI for inclusive_1_0' do
      canonicalizer = described_class.new(algorithm: :inclusive_1_0)
      expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/TR/2001/REC-xml-c14n-20010315')
    end

    it 'returns correct URI for inclusive_1_1' do
      canonicalizer = described_class.new(algorithm: :inclusive_1_1)
      expect(canonicalizer.algorithm_id).to eq('http://www.w3.org/2006/12/xml-c14n11')
    end
  end

  describe '#mode' do
    it 'returns Nokogiri constant for exclusive_1_0' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0)
      expect(canonicalizer.mode).to eq(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
    end

    it 'returns Nokogiri constant for inclusive_1_0' do
      canonicalizer = described_class.new(algorithm: :inclusive_1_0)
      expect(canonicalizer.mode).to eq(Nokogiri::XML::XML_C14N_1_0)
    end

    it 'returns Nokogiri constant for inclusive_1_1' do
      canonicalizer = described_class.new(algorithm: :inclusive_1_1)
      expect(canonicalizer.mode).to eq(Nokogiri::XML::XML_C14N_1_1)
    end
  end

  describe '#with_comments?' do
    it 'returns false for algorithms without comments' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0)
      expect(canonicalizer.with_comments?).to be false
    end

    it 'returns true for algorithms with comments' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0_with_comments)
      expect(canonicalizer.with_comments?).to be true
    end
  end

  describe '#exclusive?' do
    it 'returns true for exclusive algorithms' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0)
      expect(canonicalizer.exclusive?).to be true
    end

    it 'returns true for exclusive algorithms with comments' do
      canonicalizer = described_class.new(algorithm: :exclusive_1_0_with_comments)
      expect(canonicalizer.exclusive?).to be true
    end

    it 'returns false for inclusive algorithms' do
      canonicalizer = described_class.new(algorithm: :inclusive_1_0)
      expect(canonicalizer.exclusive?).to be false
    end
  end

  describe '.canonicalize (class method)' do
    let(:xml) { '<root><child>text</child></root>' }
    let(:doc) { Nokogiri::XML(xml) }

    it 'canonicalizes with default settings' do
      result = described_class.canonicalize(doc.root)
      expect(result).to include('<root>')
    end

    it 'accepts algorithm option' do
      result = described_class.canonicalize(doc.root, algorithm: :inclusive_1_0)
      expect(result).to be_a(String)
    end

    it 'accepts inclusive_namespaces option' do
      result = described_class.canonicalize(doc.root, inclusive_namespaces: ['ns'])
      expect(result).to be_a(String)
    end
  end

  describe 'canonicalization consistency' do
    let(:xml) { '<root attr="value"><child>text</child></root>' }
    let(:doc) { Nokogiri::XML(xml) }

    it 'produces same output for same input' do
      canonicalizer = described_class.new
      result1 = canonicalizer.canonicalize(doc.root)
      result2 = canonicalizer.canonicalize(doc.root)

      expect(result1).to eq(result2)
    end

    it 'produces same output regardless of original formatting' do
      xml1 = '<root><child>text</child></root>'
      xml2 = "<root>\n  <child>text</child>\n</root>"

      doc1 = Nokogiri::XML(xml1, &:noblanks)
      doc2 = Nokogiri::XML(xml2, &:noblanks)

      canonicalizer = described_class.new
      result1 = canonicalizer.canonicalize(doc1.root)
      result2 = canonicalizer.canonicalize(doc2.root)

      expect(result1).to eq(result2)
    end
  end

  describe 'WS-Security specific scenarios' do
    subject(:canonicalizer) { described_class.new(algorithm: :exclusive_1_0) }

    let(:soap_envelope) do
      <<~XML
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                       xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
          <soap:Header>
            <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
              <wsu:Timestamp wsu:Id="Timestamp-123">
                <wsu:Created>2026-02-01T12:00:00Z</wsu:Created>
                <wsu:Expires>2026-02-01T12:05:00Z</wsu:Expires>
              </wsu:Timestamp>
            </wsse:Security>
          </soap:Header>
          <soap:Body wsu:Id="Body-456">
            <content>data</content>
          </soap:Body>
        </soap:Envelope>
      XML
    end

    let(:doc) { Nokogiri::XML(soap_envelope, &:noblanks) }

    it 'can canonicalize SOAP Body for signing' do
      body = doc.at_xpath(
        '//soap:Body',
        'soap' => 'http://schemas.xmlsoap.org/soap/envelope/'
      )

      result = canonicalizer.canonicalize(body)

      expect(result).to include('Body')
      expect(result).to include('<content>data</content>')
    end

    it 'can canonicalize Timestamp for signing' do
      timestamp = doc.at_xpath(
        '//wsu:Timestamp',
        'wsu' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
      )

      result = canonicalizer.canonicalize(timestamp)

      expect(result).to include('Timestamp')
      expect(result).to include('Created')
      expect(result).to include('Expires')
    end
  end
end
