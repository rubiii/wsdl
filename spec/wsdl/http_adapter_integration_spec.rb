# frozen_string_literal: true

require 'spec_helper'

# WebMock intercepts at the net/http socket layer, so the full adapter code
# path (URI parsing, Net::HTTP.new, config, start, request, response parsing)
# is exercised — unlike the unit spec which mocks Net::HTTP at the class level.
describe WSDL::HTTPAdapter do
  subject(:http) { described_class.new }

  describe '#get' do
    it 'fetches a response from an HTTP endpoint' do
      stub_request(:get, 'http://example.com/service.wsdl')
        .to_return(status: 200, body: '<definitions/>', headers: { 'Content-Type' => 'text/xml' })

      response = http.get('http://example.com/service.wsdl')

      expect(response).to be_a(WSDL::HTTPResponse)
      expect(response.status).to eq(200)
      expect(response.body).to eq('<definitions/>')
      expect(response.headers['content-type']).to eq('text/xml')
    end

    it 'returns non-200 statuses' do
      stub_request(:get, 'http://example.com/missing')
        .to_return(status: 404, body: 'not found')

      response = http.get('http://example.com/missing')

      expect(response.status).to eq(404)
      expect(response.body).to eq('not found')
    end
  end

  describe '#post' do
    it 'sends headers and body to the endpoint' do
      stub_request(:post, 'http://example.com/endpoint')
        .with(body: '<request/>', headers: { 'Content-Type' => 'text/xml' })
        .to_return(status: 200, body: '<response/>')

      response = http.post('http://example.com/endpoint', { 'Content-Type' => 'text/xml' }, '<request/>')

      expect(response.status).to eq(200)
      expect(response.body).to eq('<response/>')
    end
  end

  describe 'redirect following' do
    it 'follows a 302 redirect to the final destination' do
      stub_request(:get, 'http://example.com/old')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/new' })
      stub_request(:get, 'http://example.com/new')
        .to_return(status: 200, body: 'arrived')

      response = http.get('http://example.com/old')

      expect(response.status).to eq(200)
      expect(response.body).to eq('arrived')
    end

    it 'follows a chain of redirects' do
      stub_request(:get, 'http://example.com/a')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/b' })
      stub_request(:get, 'http://example.com/b')
        .to_return(status: 301, headers: { 'Location' => 'http://example.com/c' })
      stub_request(:get, 'http://example.com/c')
        .to_return(status: 200, body: 'final')

      response = http.get('http://example.com/a')

      expect(response.status).to eq(200)
      expect(response.body).to eq('final')
    end

    it 'raises TooManyRedirectsError on a redirect loop' do
      stub_request(:get, 'http://example.com/loop-a')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/loop-b' })
      stub_request(:get, 'http://example.com/loop-b')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/loop-a' })

      expect { http.get('http://example.com/loop-a') }
        .to raise_error(WSDL::TooManyRedirectsError)
    end

    it 'changes POST to GET on 303 redirect' do
      stub_request(:post, 'http://example.com/submit')
        .to_return(status: 303, headers: { 'Location' => 'http://example.com/result' })
      stub_request(:get, 'http://example.com/result')
        .to_return(status: 200, body: 'done')

      response = http.post('http://example.com/submit', { 'Content-Type' => 'text/xml' }, '<data/>')

      expect(response.status).to eq(200)
      expect(response.body).to eq('done')
    end

    it 'preserves POST method on 307 redirect' do
      stub_request(:post, 'http://example.com/old')
        .to_return(status: 307, headers: { 'Location' => 'http://example.com/new' })
      stub_request(:post, 'http://example.com/new')
        .to_return(status: 200, body: 'done')

      response = http.post('http://example.com/old', { 'Content-Type' => 'text/xml' }, '<data/>')

      expect(response.status).to eq(200)
      expect(response.body).to eq('done')
    end

    it 'handles relative Location headers' do
      stub_request(:get, 'http://example.com/dir/page')
        .to_return(status: 302, headers: { 'Location' => '/other' })
      stub_request(:get, 'http://example.com/other')
        .to_return(status: 200, body: 'resolved')

      response = http.get('http://example.com/dir/page')

      expect(response.status).to eq(200)
      expect(response.body).to eq('resolved')
    end
  end

  describe 'SSRF protection during redirects' do
    it 'blocks redirects to loopback addresses' do
      stub_request(:get, 'http://example.com/evil')
        .to_return(status: 302, headers: { 'Location' => 'http://127.0.0.1/secret' })

      expect { http.get('http://example.com/evil') }
        .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
    end

    it 'blocks redirects to private network addresses' do
      stub_request(:get, 'http://example.com/evil')
        .to_return(status: 302, headers: { 'Location' => 'http://10.0.0.1/internal' })

      expect { http.get('http://example.com/evil') }
        .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
    end

    it 'blocks redirects to link-local metadata service' do
      stub_request(:get, 'http://example.com/evil')
        .to_return(status: 302, headers: { 'Location' => 'http://169.254.169.254/latest/meta-data/' })

      expect { http.get('http://example.com/evil') }
        .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
    end
  end

  describe 'HTTPS to HTTP downgrade protection' do
    it 'blocks HTTPS to HTTP downgrades on redirect' do
      stub_request(:get, 'https://example.com/secure')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/insecure' })

      expect { http.get('https://example.com/secure') }
        .to raise_error(WSDL::UnsafeRedirectError, /HTTPS to HTTP downgrade/)
    end
  end

  describe 'gzip protection' do
    it 'sends Accept-Encoding: identity to prevent gzip bombs' do
      stub_request(:get, 'http://example.com/check')
        .with(headers: { 'Accept-Encoding' => 'identity' })
        .to_return(status: 200, body: 'ok')

      response = http.get('http://example.com/check')

      expect(response.status).to eq(200)
    end
  end

  describe 'timeouts' do
    it 'raises on read timeout' do
      stub_request(:get, 'http://example.com/slow').to_timeout

      expect { http.get('http://example.com/slow') }.to raise_error(Net::OpenTimeout)
    end
  end

  describe 'config is applied to real Net::HTTP instances' do
    it 'uses configured timeouts' do
      http.config.open_timeout = 7
      http.config.read_timeout = 13
      http.config.write_timeout = 42

      stub_request(:get, 'http://example.com/test').to_return(status: 200, body: 'ok')

      captured_http = nil
      allow(Net::HTTP).to receive(:new).and_wrap_original do |method, *args, **kwargs|
        method.call(*args, **kwargs).tap { |h| captured_http = h }
      end

      http.get('http://example.com/test')

      expect(captured_http.open_timeout).to eq(7)
      expect(captured_http.read_timeout).to eq(13)
      expect(captured_http.write_timeout).to eq(42)
    end
  end
end
