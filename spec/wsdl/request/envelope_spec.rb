# frozen_string_literal: true

RSpec.describe WSDL::Request::Envelope do
  describe '#namespace_uri_for' do
    it 'returns the URI for a declared prefix' do
      envelope = described_class.new
      envelope.namespace_decls << WSDL::Request::NamespaceDecl.new('ns', 'http://example.com')

      expect(envelope.namespace_uri_for('ns')).to eq('http://example.com')
    end

    it 'returns nil for an undeclared prefix' do
      envelope = described_class.new

      expect(envelope.namespace_uri_for('missing')).to be_nil
    end
  end
end
