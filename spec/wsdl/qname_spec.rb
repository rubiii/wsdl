# frozen_string_literal: true

RSpec.describe WSDL::QName do
  let(:namespaces) do
    {
      'xmlns:tns' => 'http://example.com/target',
      'xmlns:other' => 'http://example.com/other',
      'xmlns' => 'http://example.com/default'
    }
  end

  describe '.resolve' do
    context 'with prefixed qname' do
      it 'returns [namespace, local] pair' do
        expect(described_class.resolve('tns:User', namespaces:))
          .to eq(['http://example.com/target', 'User'])
      end

      it 'handles different prefixes' do
        expect(described_class.resolve('other:Order', namespaces:))
          .to eq(['http://example.com/other', 'Order'])
      end

      it 'returns nil namespace for unknown prefix' do
        expect(described_class.resolve('unknown:Thing', namespaces:))
          .to eq([nil, 'Thing'])
      end
    end

    context 'without prefix' do
      it 'uses default namespace from xmlns' do
        expect(described_class.resolve('User', namespaces:))
          .to eq(['http://example.com/default', 'User'])
      end

      it 'returns nil when no default namespace' do
        expect(described_class.resolve('User', namespaces: { 'xmlns:tns' => 'http://example.com' }))
          .to eq([nil, 'User'])
      end

      it 'uses explicit default_namespace parameter when no xmlns' do
        expect(described_class.resolve('User', namespaces: {}, default_namespace: 'http://fallback.com'))
          .to eq(['http://fallback.com', 'User'])
      end

      it 'prefers xmlns over default_namespace parameter' do
        expect(described_class.resolve('User', namespaces:, default_namespace: 'http://fallback.com'))
          .to eq(['http://example.com/default', 'User'])
      end
    end

    context 'with empty namespaces hash' do
      it 'returns nil namespace for prefixed qname' do
        expect(described_class.resolve('tns:User', namespaces: {}))
          .to eq([nil, 'User'])
      end

      it 'returns nil namespace for unprefixed qname without default' do
        expect(described_class.resolve('User', namespaces: {}))
          .to eq([nil, 'User'])
      end

      it 'uses default_namespace for unprefixed qname' do
        expect(described_class.resolve('User', namespaces: {}, default_namespace: 'http://default.com'))
          .to eq(['http://default.com', 'User'])
      end
    end

    context 'with XSD namespace prefixes' do
      let(:xsd_namespaces) do
        {
          'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'
        }
      end

      it 'expands xs:string' do
        expect(described_class.resolve('xs:string', namespaces: xsd_namespaces))
          .to eq(['http://www.w3.org/2001/XMLSchema', 'string'])
      end

      it 'expands xsd:int' do
        expect(described_class.resolve('xsd:int', namespaces: xsd_namespaces))
          .to eq(['http://www.w3.org/2001/XMLSchema', 'int'])
      end
    end

    context 'with qnames containing multiple colons' do
      it 'splits on last colon' do
        expect(described_class.resolve('ns:some:value', namespaces: { 'xmlns:ns:some' => 'http://example.com' }))
          .to eq(['http://example.com', 'value'])
      end
    end
  end

  describe '.parse' do
    context 'with prefixed qname' do
      it 'resolves to local name and namespace URI' do
        result = described_class.parse('tns:User', namespaces:)
        expect(result.local).to eq('User')
        expect(result.namespace).to eq('http://example.com/target')
      end

      it 'handles different prefixes' do
        result = described_class.parse('other:Order', namespaces:)
        expect(result.local).to eq('Order')
        expect(result.namespace).to eq('http://example.com/other')
      end

      it 'returns nil namespace for unknown prefix' do
        result = described_class.parse('unknown:Thing', namespaces:)
        expect(result.local).to eq('Thing')
        expect(result.namespace).to be_nil
      end
    end

    context 'without prefix' do
      it 'uses default namespace from xmlns' do
        result = described_class.parse('User', namespaces:)
        expect(result.local).to eq('User')
        expect(result.namespace).to eq('http://example.com/default')
      end

      it 'returns nil when no default namespace' do
        result = described_class.parse('User', namespaces: { 'xmlns:tns' => 'http://example.com' })
        expect(result.local).to eq('User')
        expect(result.namespace).to be_nil
      end

      it 'uses explicit default_namespace parameter when no xmlns' do
        result = described_class.parse('User', namespaces: {}, default_namespace: 'http://fallback.com')
        expect(result.local).to eq('User')
        expect(result.namespace).to eq('http://fallback.com')
      end

      it 'prefers xmlns over default_namespace parameter' do
        result = described_class.parse('User', namespaces:, default_namespace: 'http://fallback.com')
        expect(result.local).to eq('User')
        expect(result.namespace).to eq('http://example.com/default')
      end
    end

    context 'with empty namespaces hash' do
      it 'returns nil namespace for prefixed qname' do
        result = described_class.parse('tns:User', namespaces: {})
        expect(result.local).to eq('User')
        expect(result.namespace).to be_nil
      end

      it 'returns nil namespace for unprefixed qname without default' do
        result = described_class.parse('User', namespaces: {})
        expect(result.local).to eq('User')
        expect(result.namespace).to be_nil
      end

      it 'uses default_namespace for unprefixed qname' do
        result = described_class.parse('User', namespaces: {}, default_namespace: 'http://default.com')
        expect(result.local).to eq('User')
        expect(result.namespace).to eq('http://default.com')
      end
    end

    context 'with XSD namespace prefixes' do
      let(:xsd_namespaces) do
        {
          'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'
        }
      end

      it 'expands xs:string' do
        result = described_class.parse('xs:string', namespaces: xsd_namespaces)
        expect(result.local).to eq('string')
        expect(result.namespace).to eq('http://www.w3.org/2001/XMLSchema')
      end

      it 'expands xsd:int' do
        result = described_class.parse('xsd:int', namespaces: xsd_namespaces)
        expect(result.local).to eq('int')
        expect(result.namespace).to eq('http://www.w3.org/2001/XMLSchema')
      end
    end

    context 'with qnames containing multiple colons' do
      it 'splits on last colon' do
        result = described_class.parse('ns:some:value', namespaces: { 'xmlns:ns:some' => 'http://example.com' })
        expect(result.local).to eq('value')
        expect(result.namespace).to eq('http://example.com')
      end
    end

    it 'raises ArgumentError for non-string input' do
      expect { described_class.parse(nil, namespaces: {}) }.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError for empty string' do
      expect { described_class.parse('', namespaces: {}) }.to raise_error(ArgumentError)
    end
  end

  describe '.document_namespace' do
    it 'returns targetNamespace when present' do
      root = Nokogiri::XML('<definitions targetNamespace="http://example.com"/>').root
      expect(described_class.document_namespace(root)).to eq('http://example.com')
    end

    it 'raises UnresolvedReferenceError when targetNamespace is missing' do
      root = Nokogiri::XML('<definitions/>').root
      expect { described_class.document_namespace(root) }
        .to raise_error(WSDL::UnresolvedReferenceError, /missing required targetNamespace/)
    end

    it 'raises UnresolvedReferenceError when targetNamespace is empty' do
      root = Nokogiri::XML('<definitions targetNamespace=""/>').root
      expect { described_class.document_namespace(root) }
        .to raise_error(WSDL::UnresolvedReferenceError, /missing required targetNamespace/)
    end
  end

  describe '#to_s' do
    it 'returns Clark notation with namespace' do
      qname = described_class.new('http://example.com', 'User')
      expect(qname.to_s).to eq('{http://example.com}User')
    end

    it 'returns local name only without namespace' do
      qname = described_class.new(nil, 'User')
      expect(qname.to_s).to eq('User')
    end
  end
end
