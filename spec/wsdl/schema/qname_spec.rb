# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Schema::QName do
  subject(:instance) { test_class.new }

  let(:test_class) do
    Class.new do
      include WSDL::Schema::QName
    end
  end

  describe '#split_qname' do
    it 'splits a prefixed qname into local name and prefix' do
      local, prefix = instance.split_qname('tns:User')
      expect(local).to eq('User')
      expect(prefix).to eq('tns')
    end

    it 'splits a non-prefixed qname into local name and nil prefix' do
      local, prefix = instance.split_qname('User')
      expect(local).to eq('User')
      expect(prefix).to be_nil
    end

    it 'handles qnames with multiple colons (splits on all colons)' do
      # NOTE: valid XSD qnames only have one colon, so this edge case
      # isn't realistic but documents the actual behavior
      local, prefix = instance.split_qname('ns:some:value')
      expect(local).to eq('value')
      expect(prefix).to eq('some')
    end
  end

  describe '#expand_qname' do
    let(:namespaces) do
      {
        'xmlns:tns' => 'http://example.com/target',
        'xmlns:other' => 'http://example.com/other',
        'xmlns' => 'http://example.com/default'
      }
    end

    context 'with prefixed qname' do
      it 'expands to local name and namespace URI' do
        local, namespace = instance.expand_qname('tns:User', namespaces)
        expect(local).to eq('User')
        expect(namespace).to eq('http://example.com/target')
      end

      it 'handles different prefixes' do
        local, namespace = instance.expand_qname('other:Order', namespaces)
        expect(local).to eq('Order')
        expect(namespace).to eq('http://example.com/other')
      end

      it 'returns nil namespace for unknown prefix' do
        local, namespace = instance.expand_qname('unknown:Thing', namespaces)
        expect(local).to eq('Thing')
        expect(namespace).to be_nil
      end
    end

    context 'without prefix' do
      it 'uses default namespace from xmlns' do
        local, namespace = instance.expand_qname('User', namespaces)
        expect(local).to eq('User')
        expect(namespace).to eq('http://example.com/default')
      end

      it 'returns nil when no default namespace' do
        local, namespace = instance.expand_qname('User', { 'xmlns:tns' => 'http://example.com' })
        expect(local).to eq('User')
        expect(namespace).to be_nil
      end

      it 'uses explicit default_namespace parameter when no xmlns' do
        local, namespace = instance.expand_qname('User', {}, 'http://fallback.com')
        expect(local).to eq('User')
        expect(namespace).to eq('http://fallback.com')
      end

      it 'prefers xmlns over default_namespace parameter' do
        local, namespace = instance.expand_qname('User', namespaces, 'http://fallback.com')
        expect(local).to eq('User')
        expect(namespace).to eq('http://example.com/default')
      end
    end

    context 'with empty namespaces hash' do
      it 'returns nil namespace for prefixed qname' do
        local, namespace = instance.expand_qname('tns:User', {})
        expect(local).to eq('User')
        expect(namespace).to be_nil
      end

      it 'returns nil namespace for unprefixed qname without default' do
        local, namespace = instance.expand_qname('User', {})
        expect(local).to eq('User')
        expect(namespace).to be_nil
      end

      it 'uses default_namespace for unprefixed qname' do
        local, namespace = instance.expand_qname('User', {}, 'http://default.com')
        expect(local).to eq('User')
        expect(namespace).to eq('http://default.com')
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
        local, namespace = instance.expand_qname('xs:string', xsd_namespaces)
        expect(local).to eq('string')
        expect(namespace).to eq('http://www.w3.org/2001/XMLSchema')
      end

      it 'expands xsd:int' do
        local, namespace = instance.expand_qname('xsd:int', xsd_namespaces)
        expect(local).to eq('int')
        expect(namespace).to eq('http://www.w3.org/2001/XMLSchema')
      end
    end
  end
end
