# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Source do
  describe '#url?' do
    it 'returns true for HTTP(S) URLs' do
      expect(described_class.new('http://example.com/service.wsdl').url?).to be(true)
      expect(described_class.new('https://example.com/service.wsdl').url?).to be(true)
    end

    it 'returns false for file paths' do
      expect(described_class.new('/tmp/service.wsdl').url?).to be(false)
    end
  end

  describe '#file_path?' do
    it 'returns true for absolute and relative file paths' do
      expect(described_class.new('/tmp/service.wsdl').file_path?).to be(true)
      expect(described_class.new('spec/fixtures/wsdl/amazon.wsdl').file_path?).to be(true)
    end

    it 'returns false for URLs and unsupported URI schemes' do
      expect(described_class.new('https://example.com/service.wsdl').file_path?).to be(false)
      expect(described_class.new('ftp://example.com/service.wsdl').file_path?).to be(false)
    end

    it 'treats Windows drive-relative paths as file paths' do
      source = described_class.new('C:service.wsdl')

      expect(source.file_path?).to be(true)
      expect(source.relative_file_path?).to be(true)
      expect(source.absolute_file_path?).to be(false)
      expect(source.unsupported_scheme?).to be(false)
    end

    it 'treats Windows drive-absolute paths as absolute file paths' do
      source = described_class.new('C:/service.wsdl')

      expect(source.file_path?).to be(true)
      expect(source.absolute_file_path?).to be(true)
      expect(source.relative_file_path?).to be(false)
    end
  end

  describe '#unsupported_scheme?' do
    it 'returns true for non-HTTP URI schemes' do
      expect(described_class.new('ftp://example.com/service.wsdl').unsupported_scheme?).to be(true)
      expect(described_class.new('mailto:wsdl@example.com').unsupported_scheme?).to be(true)
    end

    it 'returns false for HTTP(S) URLs and file paths' do
      expect(described_class.new('https://example.com/service.wsdl').unsupported_scheme?).to be(false)
      expect(described_class.new('/tmp/service.wsdl').unsupported_scheme?).to be(false)
    end
  end

  describe '#default_sandbox_paths' do
    it 'returns nil for URLs' do
      source = described_class.new('https://example.com/service.wsdl')

      expect(source.default_sandbox_paths).to be_nil
    end

    it 'returns the source directory for file paths' do
      source = described_class.new('spec/fixtures/wsdl/amazon.wsdl')

      expect(source.default_sandbox_paths).to eq([File.dirname(File.expand_path(source.value))])
    end

    it 'returns nil for non-URL, non-file-path sources' do
      source = described_class.new('ftp://example.com/service.wsdl')

      expect(source.default_sandbox_paths).to be_nil
    end
  end

  describe '#resolve_sandbox_paths' do
    context 'with explicit paths' do
      it 'returns the explicit paths for a URL source' do
        source = described_class.new('https://example.com/service.wsdl')

        expect(source.resolve_sandbox_paths(['/custom/path'])).to eq(['/custom/path'])
      end

      it 'returns the explicit paths for a file source' do
        source = described_class.new('spec/fixtures/wsdl/amazon.wsdl')

        expect(source.resolve_sandbox_paths(['/custom/path'])).to eq(['/custom/path'])
      end
    end

    context 'with nil sentinel' do
      it 'returns nil for URL sources' do
        source = described_class.new('https://example.com/service.wsdl')

        expect(source.resolve_sandbox_paths(nil)).to be_nil
      end

      it 'returns default sandbox paths for file sources' do
        source = described_class.new('spec/fixtures/wsdl/amazon.wsdl')

        expect(source.resolve_sandbox_paths(nil)).to eq(source.default_sandbox_paths)
      end
    end
  end

  describe '.validate_wsdl!' do
    it 'returns a source for valid inputs' do
      source = described_class.validate_wsdl!('https://example.com/service.wsdl')

      expect(source).to be_a(described_class)
      expect(source.url?).to be(true)
    end

    it 'rejects inline XML' do
      expect {
        described_class.validate_wsdl!('<definitions/>')
      }.to raise_error(ArgumentError, /Inline XML WSDL is not supported/)
    end

    it 'rejects file URLs and unsupported schemes' do
      expect {
        described_class.validate_wsdl!('file:///tmp/service.wsdl')
      }.to raise_error(ArgumentError, %r{file:// URLs are not supported})

      expect {
        described_class.validate_wsdl!('ftp://example.com/service.wsdl')
      }.to raise_error(ArgumentError, /Unsupported URL scheme/)
    end

    it 'rejects non-string and empty inputs' do
      expect { described_class.validate_wsdl!(nil) }.to raise_error(ArgumentError, /non-empty String/)
      expect { described_class.validate_wsdl!(123) }.to raise_error(ArgumentError, /non-empty String/)
      expect { described_class.validate_wsdl!('') }.to raise_error(ArgumentError, /non-empty String/)
    end
  end

  describe '#normalized_url' do
    it 'normalizes valid URLs' do
      source = described_class.new('HTTP://EXAMPLE.COM/service.wsdl')

      expect(source.normalized_url).to eq('http://example.com/service.wsdl')
    end

    it 'returns original value for invalid URIs' do
      source = described_class.new('http://[invalid')

      expect(source.normalized_url).to eq('http://[invalid')
    end
  end
end
