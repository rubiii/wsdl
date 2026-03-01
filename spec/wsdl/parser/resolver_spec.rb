# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Parser::Resolver do
  subject(:resolver) { described_class.new(http_test_client) }

  let(:http_test_client) do
    Class.new do
      def get(url)
        "raw_response for #{url}"
      end
    end.new
  end

  it 'resolves remote files using a simple HTTP client interface' do
    url = 'http://example.com?wsdl'

    xml = resolver.resolve(url)
    expect(xml).to eq("raw_response for #{url}")
  end

  it 'resolves local files' do
    fixture_path = fixture('wsdl/authentication')

    xml = resolver.resolve(fixture_path)
    expect(xml).to eq(File.read(fixture_path))
  end

  it 'simply returns any raw input' do
    string = '<xml/>'

    xml = resolver.resolve(string)
    expect(xml).to eq(string)
  end

  describe 'relative path resolution' do
    it 'resolves relative paths against a file base' do
      base = '/path/to/wsdl/service.wsdl'
      relative = '../schemas/types.xsd'

      resolved = resolver.resolve_location(relative, base)
      expect(resolved).to eq('/path/to/schemas/types.xsd')
    end

    it 'resolves relative paths against a URL base' do
      base = 'http://example.com/wsdl/service.wsdl'
      relative = '../schemas/types.xsd'

      resolved = resolver.resolve_location(relative, base)
      expect(resolved).to eq('http://example.com/schemas/types.xsd')
    end

    it 'returns absolute URLs unchanged' do
      absolute = 'http://example.com/schemas/types.xsd'

      resolved = resolver.resolve_location(absolute, '/some/base.wsdl')
      expect(resolved).to eq(absolute)
    end

    it 'returns absolute file paths unchanged' do
      absolute = '/absolute/path/to/schema.xsd'

      resolved = resolver.resolve_location(absolute, '/some/base.wsdl')
      expect(resolved).to eq(absolute)
    end

    it 'returns raw XML unchanged' do
      xml = '<schema/>'

      resolved = resolver.resolve_location(xml, '/some/base.wsdl')
      expect(resolved).to eq(xml)
    end

    it 'identifies relative locations' do
      expect(resolver.relative_location?('relative/path.xsd')).to be true
      expect(resolver.relative_location?('../path.xsd')).to be true
      expect(resolver.relative_location?('http://example.com/path.xsd')).to be false
      expect(resolver.relative_location?('/absolute/path.xsd')).to be false
      expect(resolver.relative_location?('<xml/>')).to be false
    end
  end

  describe 'error handling for relative paths' do
    it 'resolves against current directory when base is nil' do
      # This supports loading initial WSDL from relative paths like "path/to/service.wsdl"
      resolved = resolver.resolve_location('relative/path.xsd', nil)
      expect(resolved).to eq(File.expand_path('relative/path.xsd'))
    end

    it 'raises UnresolvableImportError when base is inline XML' do
      expect {
        resolver.resolve_location('relative/path.xsd', '<definitions/>')
      }.to raise_error(WSDL::UnresolvableImportError, /base is inline XML/)
    end
  end
end
