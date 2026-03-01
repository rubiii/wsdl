# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Parser::Resolver do
  subject(:resolver) { described_class.new(http_test_client, **options) }

  let(:http_test_client) do
    Class.new do
      def get(url)
        "raw_response for #{url}"
      end
    end.new
  end

  let(:options) { { file_access: :unrestricted } }

  describe '#resolve' do
    it 'resolves remote files using a simple HTTP client interface' do
      url = 'http://example.com?wsdl'

      xml = resolver.resolve(url)
      expect(xml).to eq("raw_response for #{url}")
    end

    it 'resolves local files when file access is allowed' do
      fixture_path = fixture('wsdl/authentication')

      xml = resolver.resolve(fixture_path)
      expect(xml).to eq(File.read(fixture_path))
    end

    it 'simply returns any raw input' do
      string = '<xml/>'

      xml = resolver.resolve(string)
      expect(xml).to eq(string)
    end
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

  describe 'file:// URL blocking' do
    it 'blocks file:// URLs' do
      expect {
        resolver.resolve_location('file:///etc/passwd')
      }.to raise_error(WSDL::PathRestrictionError, %r{file:// URLs are not allowed})
    end

    it 'blocks FILE:// URLs (case insensitive)' do
      expect {
        resolver.resolve_location('FILE:///etc/passwd')
      }.to raise_error(WSDL::PathRestrictionError, %r{file:// URLs are not allowed})
    end

    it 'blocks file:// URLs in relative imports' do
      expect {
        resolver.resolve_location('file:///etc/passwd', base: '/some/base.wsdl')
      }.to raise_error(WSDL::PathRestrictionError, %r{file:// URLs are not allowed})
    end
  end

  describe 'sandbox restrictions' do
    context 'with file_access: :sandbox' do
      let(:options) { { file_access: :sandbox, sandbox_paths: ['/app/wsdl', '/app/schemas'] } }

      it 'allows files within sandbox paths' do
        # Create a mock for File.read since we're testing the validation logic
        allow(File).to receive(:read).with('/app/wsdl/service.wsdl').and_return('<xml/>')

        expect { resolver.resolve('/app/wsdl/service.wsdl') }.not_to raise_error
      end

      it 'allows files in subdirectories of sandbox paths' do
        allow(File).to receive(:read).with('/app/wsdl/sub/dir/schema.xsd').and_return('<xml/>')

        expect { resolver.resolve('/app/wsdl/sub/dir/schema.xsd') }.not_to raise_error
      end

      it 'allows files in alternate sandbox path' do
        allow(File).to receive(:read).with('/app/schemas/common.xsd').and_return('<xml/>')

        expect { resolver.resolve('/app/schemas/common.xsd') }.not_to raise_error
      end

      it 'blocks files outside sandbox paths' do
        expect {
          resolver.resolve('/etc/passwd')
        }.to raise_error(WSDL::PathRestrictionError, /outside the allowed directories/)
      end

      it 'blocks path traversal attacks' do
        expect {
          resolver.resolve('/app/wsdl/../../../etc/passwd')
        }.to raise_error(WSDL::PathRestrictionError, /outside the allowed directories/)
      end

      it 'blocks path traversal via relative imports' do
        # When resolving ../../../etc/passwd against /app/wsdl/service.wsdl
        # it should resolve to /etc/passwd which is outside the sandbox
        resolved = resolver.resolve_location('../../../../etc/passwd', '/app/wsdl/service.wsdl')
        expect(resolved).to eq('/etc/passwd')

        expect {
          resolver.resolve(resolved)
        }.to raise_error(WSDL::PathRestrictionError, /outside the allowed directories/)
      end

      it 'includes the path in error messages for debugging' do
        expect {
          resolver.resolve('/etc/passwd')
        }.to raise_error(WSDL::PathRestrictionError, %r{/etc/passwd})
      end

      it 'includes allowed directories in error messages' do
        expect {
          resolver.resolve('/etc/passwd')
        }.to raise_error(WSDL::PathRestrictionError, %r{Allowed:.*/app/wsdl})
      end

      it 'mentions path traversal attack in error messages' do
        expect {
          resolver.resolve('/etc/passwd')
        }.to raise_error(WSDL::PathRestrictionError, /path traversal attack/)
      end
    end

    context 'with file_access: :sandbox but no sandbox_paths' do
      it 'raises ArgumentError immediately on initialization' do
        expect {
          described_class.new(http_test_client, file_access: :sandbox, sandbox_paths: nil)
        }.to raise_error(ArgumentError, /sandbox_paths to be specified/)
      end
    end

    context 'with file_access: :sandbox and empty sandbox_paths' do
      it 'raises ArgumentError immediately on initialization' do
        expect {
          described_class.new(http_test_client, file_access: :sandbox, sandbox_paths: [])
        }.to raise_error(ArgumentError, /sandbox_paths to be specified/)
      end
    end

    context 'with file_access: :disabled' do
      let(:options) { { file_access: :disabled } }

      it 'allows URL access' do
        xml = resolver.resolve('http://example.com/service.wsdl')
        expect(xml).to eq('raw_response for http://example.com/service.wsdl')
      end

      it 'allows raw XML' do
        xml = resolver.resolve('<xml/>')
        expect(xml).to eq('<xml/>')
      end

      it 'blocks file access' do
        expect {
          resolver.resolve('/path/to/file.wsdl')
        }.to raise_error(WSDL::PathRestrictionError, /File access is disabled/)
      end

      it 'includes helpful message about alternatives' do
        expect {
          resolver.resolve('/path/to/file.wsdl')
        }.to raise_error(WSDL::PathRestrictionError, /use file_access: :sandbox with explicit sandbox_paths/)
      end

      it 'mentions the current mode in error message' do
        expect {
          resolver.resolve('/path/to/file.wsdl')
        }.to raise_error(WSDL::PathRestrictionError, /mode: :disabled/)
      end
    end

    context 'with file_access: :unrestricted' do
      let(:options) { { file_access: :unrestricted } }

      it 'allows any file access' do
        fixture_path = fixture('wsdl/authentication')

        xml = resolver.resolve(fixture_path)
        expect(xml).to eq(File.read(fixture_path))
      end

      it 'allows files outside any sandbox' do
        # We can't actually read /etc/passwd in tests, but we can verify
        # that the validation doesn't raise an error before File.read
        allow(File).to receive(:read).with('/etc/passwd').and_return('root:x:0:0:root')

        expect { resolver.resolve('/etc/passwd') }.not_to raise_error
      end
    end
  end

  describe 'invalid file_access mode' do
    it 'raises ArgumentError immediately on initialization' do
      expect {
        described_class.new(http_test_client, file_access: :invalid_mode)
      }.to raise_error(ArgumentError, /Invalid file_access mode: :invalid_mode/)
    end

    it 'includes valid modes in error message' do
      expect {
        described_class.new(http_test_client, file_access: :bogus)
      }.to raise_error(ArgumentError, /:sandbox.*:disabled.*:unrestricted/)
    end
  end

  describe '#file_access_allowed?' do
    context 'with file_access: :disabled' do
      let(:options) { { file_access: :disabled } }

      it 'returns false' do
        expect(resolver.file_access_allowed?).to be false
      end
    end

    context 'with file_access: :sandbox' do
      let(:options) { { file_access: :sandbox, sandbox_paths: ['/app'] } }

      it 'returns true' do
        expect(resolver.file_access_allowed?).to be true
      end
    end

    context 'with file_access: :unrestricted' do
      let(:options) { { file_access: :unrestricted } }

      it 'returns true' do
        expect(resolver.file_access_allowed?).to be true
      end
    end
  end

  describe 'sandbox path normalization' do
    let(:options) { { file_access: :sandbox, sandbox_paths: ['./relative/path', '../other'] } }

    it 'normalizes relative sandbox paths to absolute paths' do
      expect(resolver.sandbox_paths).to all(start_with('/'))
    end

    it 'expands sandbox paths' do
      expect(resolver.sandbox_paths).to include(File.expand_path('./relative/path'))
      expect(resolver.sandbox_paths).to include(File.expand_path('../other'))
    end
  end

  describe 'edge cases for path comparison' do
    context 'with sandbox containing trailing slash' do
      let(:options) { { file_access: :sandbox, sandbox_paths: ['/app/wsdl/'] } }

      it 'allows files in the directory' do
        allow(File).to receive(:read).with('/app/wsdl/service.wsdl').and_return('<xml/>')

        expect { resolver.resolve('/app/wsdl/service.wsdl') }.not_to raise_error
      end
    end

    context 'with similar-looking paths (prefix attack)' do
      let(:options) { { file_access: :sandbox, sandbox_paths: ['/app/wsdl'] } }

      it 'blocks /app/wsdl-malicious (not a true subdirectory)' do
        expect {
          resolver.resolve('/app/wsdl-malicious/evil.xsd')
        }.to raise_error(WSDL::PathRestrictionError)
      end

      it 'blocks /app/wsdlmalicious (not a true subdirectory)' do
        expect {
          resolver.resolve('/app/wsdlmalicious/evil.xsd')
        }.to raise_error(WSDL::PathRestrictionError)
      end
    end

    context 'allowing the sandbox directory itself' do
      let(:options) { { file_access: :sandbox, sandbox_paths: ['/app/wsdl'] } }

      it 'allows reading the sandbox directory path itself' do
        allow(File).to receive(:read).with('/app/wsdl').and_return('<xml/>')

        expect { resolver.resolve('/app/wsdl') }.not_to raise_error
      end
    end
  end

  describe 'resource limits' do
    let(:options) { { file_access: :unrestricted } }

    describe '#limits' do
      it 'uses WSDL.limits by default' do
        expect(resolver.limits).to eq(WSDL.limits)
      end

      it 'accepts custom limits' do
        custom_limits = WSDL::Limits.new(max_document_size: 1024)
        resolver_with_limits = described_class.new(http_test_client, file_access: :unrestricted, limits: custom_limits)

        expect(resolver_with_limits.limits).to eq(custom_limits)
      end
    end

    describe 'max_document_size' do
      let(:small_file) { fixture('wsdl/authentication') }

      context 'when file size is within limit' do
        let(:options) { { file_access: :unrestricted, limits: WSDL::Limits.new(max_document_size: 10 * 1024 * 1024) } }

        it 'allows reading the file' do
          expect { resolver.resolve(small_file) }.not_to raise_error
        end
      end

      context 'when file size exceeds limit' do
        let(:options) { { file_access: :unrestricted, limits: WSDL::Limits.new(max_document_size: 10) } }

        it 'raises ResourceLimitError' do
          expect {
            resolver.resolve(small_file)
          }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
        end

        it 'includes the limit name in the error' do
          expect {
            resolver.resolve(small_file)
          }.to raise_error(WSDL::ResourceLimitError) { |e|
            expect(e.limit_name).to eq(:max_document_size)
          }
        end

        it 'includes the limit value in the error' do
          expect {
            resolver.resolve(small_file)
          }.to raise_error(WSDL::ResourceLimitError) { |e|
            expect(e.limit_value).to eq(10)
          }
        end
      end

      context 'when limit is nil (disabled)' do
        let(:options) { { file_access: :unrestricted, limits: WSDL::Limits.new(max_document_size: nil) } }

        it 'allows any file size' do
          expect { resolver.resolve(small_file) }.not_to raise_error
        end
      end

      context 'for HTTP responses' do
        let(:large_content) { 'x' * 1000 }
        let(:http_client) do
          Class.new do
            def initialize(content)
              @content = content
            end

            def get(_url)
              @content
            end
          end.new(large_content)
        end

        it 'raises ResourceLimitError when HTTP response exceeds limit' do
          limited_resolver = described_class.new(
            http_client,
            file_access: :unrestricted,
            limits: WSDL::Limits.new(max_document_size: 100)
          )

          expect {
            limited_resolver.resolve('http://example.com/large.wsdl')
          }.to raise_error(WSDL::ResourceLimitError, /exceeds limit/)
        end
      end
    end

    describe 'max_total_download_size' do
      let(:small_file) { fixture('wsdl/authentication') }
      let(:file_size) { File.size(small_file) }

      context 'when total download stays within limit' do
        let(:options) do
          {
            file_access: :unrestricted,
            limits: WSDL::Limits.new(max_total_download_size: file_size * 10)
          }
        end

        it 'allows multiple downloads' do
          3.times do
            resolver.resolve(small_file)
          end
          expect(resolver.total_bytes_downloaded).to eq(file_size * 3)
        end
      end

      context 'when total download exceeds limit' do
        let(:options) do
          {
            file_access: :unrestricted,
            limits: WSDL::Limits.new(max_total_download_size: file_size + 1)
          }
        end

        it 'raises ResourceLimitError on second download' do
          resolver.resolve(small_file)

          expect {
            resolver.resolve(small_file)
          }.to raise_error(WSDL::ResourceLimitError, /Total download size/)
        end

        it 'includes the limit name in the error' do
          resolver.resolve(small_file)

          expect {
            resolver.resolve(small_file)
          }.to raise_error(WSDL::ResourceLimitError) { |e|
            expect(e.limit_name).to eq(:max_total_download_size)
          }
        end
      end

      context 'when limit is nil (disabled)' do
        let(:options) { { file_access: :unrestricted, limits: WSDL::Limits.new(max_total_download_size: nil) } }

        it 'allows unlimited total download' do
          10.times do
            resolver.resolve(small_file)
          end
          expect(resolver.total_bytes_downloaded).to eq(file_size * 10)
        end
      end
    end

    describe '#total_bytes_downloaded' do
      it 'starts at zero' do
        expect(resolver.total_bytes_downloaded).to eq(0)
      end

      it 'accumulates bytes from file reads' do
        small_file = fixture('wsdl/authentication')
        file_size = File.size(small_file)

        resolver.resolve(small_file)
        expect(resolver.total_bytes_downloaded).to eq(file_size)
      end

      it 'accumulates bytes from HTTP responses' do
        content = 'test content'
        http_client = Class.new do
          def initialize(content)
            @content = content
          end

          def get(_url)
            @content
          end
        end.new(content)

        http_resolver = described_class.new(http_client, file_access: :unrestricted)
        http_resolver.resolve('http://example.com/test.wsdl')

        expect(http_resolver.total_bytes_downloaded).to eq(content.bytesize)
      end
    end
  end

  describe 'integration with real fixtures' do
    let(:fixture_dir) { File.expand_path('../../fixtures/wsdl', __dir__) }
    let(:options) { { file_access: :sandbox, sandbox_paths: [fixture_dir] } }

    it 'allows reading fixtures within the sandbox' do
      fixture_path = fixture('wsdl/authentication')

      xml = resolver.resolve(fixture_path)
      expect(xml).to include('definitions')
    end

    it 'resolves relative imports within the sandbox' do
      # Travelport fixture uses relative imports like ../common_v32_0/CommonReqRsp.xsd
      travelport_dir = File.join(fixture_dir, 'travelport')
      sandbox_resolver = described_class.new(http_test_client, file_access: :sandbox, sandbox_paths: [travelport_dir])

      base = File.join(travelport_dir, 'system_v32_0/System.xsd')
      resolved = sandbox_resolver.resolve_location('../common_v32_0/CommonReqRsp.xsd', base)

      expect(resolved).to eq(File.join(travelport_dir, 'common_v32_0/CommonReqRsp.xsd'))

      # Should be able to read this file
      xml = sandbox_resolver.resolve(resolved)
      expect(xml).to include('schema')
    end

    it 'blocks path traversal that escapes fixture directory' do
      expect {
        resolver.resolve_location('../../../../etc/passwd', fixture('wsdl/authentication'))
        resolver.resolve('/etc/passwd')
      }.to raise_error(WSDL::PathRestrictionError)
    end
  end
end
