# frozen_string_literal: true

require 'logger'

RSpec.describe WSDL::HTTPAdapter do
  subject(:http) { described_class.new }

  describe '#config' do
    it 'returns a Config instance' do
      expect(http.config).to be_an_instance_of(described_class::Config)
    end
  end

  describe 'Config defaults' do
    it 'sets open_timeout to 30 seconds' do
      expect(http.config.open_timeout).to eq(30)
    end

    it 'sets write_timeout to 60 seconds' do
      expect(http.config.write_timeout).to eq(60)
    end

    it 'sets read_timeout to 120 seconds' do
      expect(http.config.read_timeout).to eq(120)
    end

    it 'sets max_redirects to 5' do
      expect(http.config.max_redirects).to eq(5)
    end

    it 'sets verify_mode to VERIFY_PEER' do
      expect(http.config.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'allows customizing timeouts after initialization' do
      http.config.open_timeout = 10
      http.config.read_timeout = 300

      expect(http.config.open_timeout).to eq(10)
      expect(http.config.read_timeout).to eq(300)
    end

    it 'allows customizing max_redirects after initialization' do
      http.config.max_redirects = 10

      expect(http.config.max_redirects).to eq(10)
    end
  end

  describe 'gzip decompression' do
    it 'disables transparent gzip decompression to prevent gzip bombs' do
      request = http.send(:build_request, :get, URI('https://example.com'), {}, nil)

      expect(request['Accept-Encoding']).to eq('identity')
    end

    it 'does not allow user headers to be overwritten by the gzip protection' do
      request = http.send(:build_request, :get, URI('https://example.com'),
                          { 'Accept-Encoding' => 'gzip' }, nil)

      expect(request['Accept-Encoding']).to eq('gzip')
    end
  end

  describe 'redirect following' do
    let(:ok_net_response) do
      instance_double(Net::HTTPOK, code: '200', body: 'ok').tap do |r|
        allow(r).to receive(:each_header).and_yield('content-type', 'text/xml')
      end
    end

    let(:net_http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:ipaddr=)
      allow(net_http).to receive(:use_ssl=)
      allow(net_http).to receive(:start).and_yield
      allow(net_http).to receive(:open_timeout=)
      allow(net_http).to receive(:write_timeout=)
      allow(net_http).to receive(:read_timeout=)
      allow(net_http).to receive(:verify_mode=)
    end

    it 'follows a 302 redirect' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/old')

      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
    end

    it 'changes method to GET on 303' do
      redirect_response = instance_double(Net::HTTPSeeOther, code: '303', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/result')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.post('https://example.com/submit', { 'Content-Type' => 'text/xml' }, '<soap/>')

      expect(response.status).to eq(200)
      # Verify the second request was a GET (no body)
      expect(net_http).to have_received(:request).with(an_instance_of(Net::HTTP::Get)).at_least(:once)
    end

    it 'preserves method on 307' do
      redirect_response = instance_double(Net::HTTPTemporaryRedirect, code: '307', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.post('https://example.com/old', { 'Content-Type' => 'text/xml' }, '<soap/>')

      expect(response.status).to eq(200)
      # Verify both requests were POST
      expect(net_http).to have_received(:request).with(an_instance_of(Net::HTTP::Post)).twice
    end

    it 'raises TooManyRedirectsError when redirect limit is exceeded' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/loop')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      http.config.max_redirects = 2

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::TooManyRedirectsError, /Too many redirects/)
    end

    it 'strips sensitive headers on cross-origin 307 redirect' do
      redirect_response = instance_double(Net::HTTPTemporaryRedirect, code: '307', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://other.example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('other.example.com').and_return(['93.184.216.34'])

      request_headers = []
      allow(net_http).to receive(:request) do |req|
        request_headers << req.to_hash
        request_headers.size == 1 ? redirect_response : ok_net_response
      end

      http.post('https://example.com/api',
                { 'Authorization' => 'Bearer secret', 'Content-Type' => 'text/xml', 'Cookie' => 'session=abc' },
                '<soap/>')

      # First request should have Authorization and Cookie
      expect(request_headers[0]).to include('authorization', 'cookie')
      # Second request (cross-origin) should not
      expect(request_headers[1]).not_to include('authorization')
      expect(request_headers[1]).not_to include('cookie')
    end

    it 'preserves sensitive headers on same-origin 307 redirect' do
      redirect_response = instance_double(Net::HTTPTemporaryRedirect, code: '307', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      request_headers = []
      allow(net_http).to receive(:request) do |req|
        request_headers << req.to_hash
        request_headers.size == 1 ? redirect_response : ok_net_response
      end

      http.post('https://example.com/api',
                { 'Authorization' => 'Bearer secret', 'Content-Type' => 'text/xml' },
                '<soap/>')

      # Both requests should have Authorization
      expect(request_headers[0]).to include('authorization')
      expect(request_headers[1]).to include('authorization')
    end

    it 'strips sensitive headers on cross-origin 308 redirect' do
      redirect_response = instance_double(Net::HTTPPermanentRedirect, code: '308', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://other.example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('other.example.com').and_return(['93.184.216.34'])

      request_headers = []
      allow(net_http).to receive(:request) do |req|
        request_headers << req.to_hash
        request_headers.size == 1 ? redirect_response : ok_net_response
      end

      http.post('https://example.com/api',
                { 'Authorization' => 'Bearer secret', 'Content-Type' => 'text/xml' },
                '<soap/>')

      expect(request_headers[1]).not_to include('authorization')
      # Content-Type should be preserved (not sensitive)
      expect(request_headers[1]).to include('content-type')
    end

    it 'preserves sensitive headers on http to https upgrade to same host' do
      redirect_response = instance_double(Net::HTTPTemporaryRedirect, code: '307', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      request_headers = []
      allow(net_http).to receive(:request) do |req|
        request_headers << req.to_hash
        request_headers.size == 1 ? redirect_response : ok_net_response
      end

      http.post('http://example.com/api',
                { 'Authorization' => 'Bearer secret', 'Content-Type' => 'text/xml' },
                '<soap/>')

      # http→https on same host is a TLS upgrade, not a cross-origin redirect
      expect(request_headers[1]).to include('authorization')
    end

    it 'pins the resolved IP on the connection to prevent DNS rebinding' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://rebind.example.com/target')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('rebind.example.com').and_return(['93.184.216.34'])

      http.get('https://example.com/start')

      expect(net_http).to have_received(:ipaddr=).with('93.184.216.34')
    end

    it 'pins the IP literal directly without DNS resolution' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://93.184.216.34/target')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)

      http.get('https://example.com/start')

      expect(net_http).to have_received(:ipaddr=).with('93.184.216.34')
    end

    it 'does not pin an IP for the initial (non-redirect) request' do
      allow(net_http).to receive(:request).and_return(ok_net_response)

      http.get('https://example.com/start')

      expect(net_http).not_to have_received(:ipaddr=)
    end

    it 'raises immediately when a redirect has no Location header' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header).and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response)

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::UnsafeRedirectError, /no Location header/)
    end

    it 'raises immediately when a redirect has a blank Location header' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', "  \t\n  ")
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response)

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::UnsafeRedirectError, /no Location header/)
    end

    it 'raises on a malformed Location header' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'http://[::1')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response)

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::UnsafeRedirectError, /malformed Location header/)
    end

    it 'resolves a relative path redirect against the original URI' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', '/new/path')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/old/path')

      expect(response.status).to eq(200)
      expect(net_http).to have_received(:request).with(
        an_object_satisfying { |req| req.path == '/new/path' }
      ).at_least(:once)
    end

    it 'resolves a scheme-relative redirect against the original URI' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', '//other.example.com/path')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('other.example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/start')

      expect(response.status).to eq(200)
      expect(Net::HTTP).to have_received(:new).with('other.example.com', 443)
    end

    it 'changes method to GET on 301' do
      redirect_response = instance_double(Net::HTTPMovedPermanently, code: '301', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/result')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.post('https://example.com/submit', { 'Content-Type' => 'text/xml' }, '<soap/>')

      expect(response.status).to eq(200)
      expect(net_http).to have_received(:request).with(an_instance_of(Net::HTTP::Get)).at_least(:once)
    end

    it 'preserves method on 308' do
      redirect_response = instance_double(Net::HTTPPermanentRedirect, code: '308', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/new')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.post('https://example.com/old', { 'Content-Type' => 'text/xml' }, '<soap/>')

      expect(response.status).to eq(200)
      expect(net_http).to have_received(:request).with(an_instance_of(Net::HTTP::Post)).twice
    end

    it 'follows a chain of redirects (301 → 302 → 200)' do
      first_redirect = instance_double(Net::HTTPMovedPermanently, code: '301', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/step2')
          .and_yield('content-type', 'text/html')
      end

      second_redirect = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://example.com/final')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(first_redirect, second_redirect, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/start')

      expect(response.status).to eq(200)
      expect(response.body).to eq('ok')
      expect(net_http).to have_received(:request).exactly(3).times
    end

    it 'blocks SSRF on the second redirect in a chain' do
      public_redirect = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://evil.example.com/redir')
          .and_yield('content-type', 'text/html')
      end

      private_redirect = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://10.0.0.1/internal')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(public_redirect, private_redirect)
      allow(Resolv).to receive(:getaddresses).with('evil.example.com').and_return(['93.184.216.34'])

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
    end

    it 'follows a redirect chain mixing DNS names and IP literals' do
      dns_redirect = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://redirect.example.com/step')
          .and_yield('content-type', 'text/html')
      end

      ip_redirect = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', 'https://93.184.216.34/final')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(dns_redirect, ip_redirect, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('redirect.example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/start')

      expect(response.status).to eq(200)
      expect(net_http).to have_received(:request).exactly(3).times
    end

    it 'resolves a query-only redirect against the original URI' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header)
          .and_yield('location', '?param=value')
          .and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response, ok_net_response)
      allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])

      response = http.get('https://example.com/path')

      expect(response.status).to eq(200)
      expect(net_http).to have_received(:request).with(
        an_object_satisfying { |req| req.path == '/path?param=value' }
      ).at_least(:once)
    end
  end

  describe '#resolve_redirect_uri' do
    let(:base_uri) { URI.parse('https://example.com/old/path?q=1') }

    def make_response(location)
      WSDL::HTTPResponse.new(
        status: 302,
        headers: location ? { 'location' => location } : {},
        body: ''
      )
    end

    it 'returns an absolute URL as-is' do
      result = http.send(:resolve_redirect_uri, base_uri, make_response('https://other.com/new'))

      expect(result).to eq(URI.parse('https://other.com/new'))
    end

    it 'resolves a relative path against the original URI' do
      result = http.send(:resolve_redirect_uri, base_uri, make_response('/new/path'))

      expect(result).to eq(URI.parse('https://example.com/new/path'))
    end

    it 'resolves a scheme-relative URL inheriting the original scheme' do
      result = http.send(:resolve_redirect_uri, base_uri, make_response('//other.com/path'))

      expect(result.scheme).to eq('https')
      expect(result.host).to eq('other.com')
      expect(result.path).to eq('/path')
    end

    it 'resolves a query-only Location against the original URI' do
      result = http.send(:resolve_redirect_uri, base_uri, make_response('?new=2'))

      expect(result.host).to eq('example.com')
      expect(result.path).to eq('/old/path')
      expect(result.query).to eq('new=2')
    end

    it 'raises UnsafeRedirectError when Location is missing' do
      expect { http.send(:resolve_redirect_uri, base_uri, make_response(nil)) }
        .to raise_error(WSDL::UnsafeRedirectError, /no Location header/)
    end

    it 'raises UnsafeRedirectError when Location is blank' do
      expect { http.send(:resolve_redirect_uri, base_uri, make_response('   ')) }
        .to raise_error(WSDL::UnsafeRedirectError, /no Location header/)
    end

    it 'raises UnsafeRedirectError for a malformed Location' do
      expect { http.send(:resolve_redirect_uri, base_uri, make_response('http://[::1')) }
        .to raise_error(WSDL::UnsafeRedirectError, /malformed Location header/)
    end

    it 'truncates long malformed Location in the error message' do
      long_location = "http://[#{'x' * 300}"

      expect { http.send(:resolve_redirect_uri, base_uri, make_response(long_location)) }
        .to raise_error(WSDL::UnsafeRedirectError) { |error|
          expect(error.message).to include(long_location[0, 200])
          expect(error.message).not_to include(long_location)
        }
    end
  end

  describe '#strip_sensitive_headers' do
    it 'removes sensitive headers case-insensitively' do
      headers = {
        'Authorization' => 'Bearer token',
        'COOKIE' => 'session=abc',
        'Proxy-Authorization' => 'Basic creds',
        'Content-Type' => 'text/xml',
        'X-Custom' => 'keep'
      }

      result = http.send(:strip_sensitive_headers, headers)

      expect(result).to eq('Content-Type' => 'text/xml', 'X-Custom' => 'keep')
    end
  end

  describe 'SSL verification' do
    it 'has SSL verification enabled by default' do
      expect(http.ssl_verification_disabled?).to be false
    end

    it 'detects when SSL verification is disabled' do
      http.config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      expect(http.ssl_verification_disabled?).to be true
    end
  end

  describe 'SSL verification warning' do
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output) }
    let(:net_http) { instance_double(Net::HTTP) }
    let(:net_response) do
      instance_double(Net::HTTPOK, code: '200', body: 'response').tap do |r|
        allow(r).to receive(:each_header).and_yield('content-type', 'text/xml')
      end
    end

    before do
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:use_ssl=)
      allow(net_http).to receive(:start).and_yield
      allow(net_http).to receive(:open_timeout=)
      allow(net_http).to receive(:write_timeout=)
      allow(net_http).to receive(:read_timeout=)
      allow(net_http).to receive(:verify_mode=)
      allow(net_http).to receive(:request).and_return(net_response)
      WSDL.logger = logger
    end

    context 'when SSL verification is enabled' do
      it 'does not log a warning on GET' do
        http.get('https://example.com')

        expect(log_output.string).to be_empty
      end

      it 'does not log a warning on POST' do
        http.post('https://example.com', {}, 'body')

        expect(log_output.string).to be_empty
      end
    end

    context 'when SSL verification is disabled' do
      before do
        http.config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      it 'logs a warning on GET' do
        http.get('https://example.com')

        expect(log_output.string).to match(/SSL certificate verification is disabled/)
      end

      it 'logs a warning on POST' do
        http.post('https://example.com', {}, 'body')

        expect(log_output.string).to match(/SSL certificate verification is disabled/)
      end

      it 'mentions man-in-the-middle attacks in the warning' do
        http.get('https://example.com')

        expect(log_output.string).to match(/man-in-the-middle/)
      end

      it 'only logs the warning once per adapter instance' do
        http.get('https://example.com')
        http.get('https://example.com')
        http.post('https://example.com', {}, 'body')

        expect(log_output.string.scan('SSL certificate verification is disabled').length).to eq(1)
      end

      it 'logs again for a new adapter instance' do
        http2 = described_class.new
        http2.config.verify_mode = OpenSSL::SSL::VERIFY_NONE

        http.get('https://example.com')
        http2.get('https://example.com')

        expect(log_output.string.scan('SSL certificate verification is disabled').length).to eq(2)
      end
    end
  end

  describe 'config is applied before connection' do
    it 'sets timeouts and SSL config before starting the connection' do
      net_response = instance_double(Net::HTTPOK, code: '200', body: 'ok').tap do |r|
        allow(r).to receive(:each_header)
      end

      call_order = []
      net_http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:use_ssl=)
      allow(net_http).to receive(:open_timeout=) { call_order << :config }
      allow(net_http).to receive(:write_timeout=)
      allow(net_http).to receive(:read_timeout=)
      allow(net_http).to receive(:verify_mode=)
      allow(net_http).to receive(:request).and_return(net_response)
      allow(net_http).to receive(:start) do |&block|
        call_order << :start
        block.call
      end

      http.get('https://example.com')

      expect(call_order).to eq(%i[config start])
    end
  end

  describe '#get' do
    it 'returns an HTTPResponse with status, headers, and body' do
      net_response = instance_double(Net::HTTPOK, code: '200', body: 'raw get!').tap do |r|
        allow(r).to receive(:each_header).and_yield('content-type', 'text/xml')
      end

      net_http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:use_ssl=)
      allow(net_http).to receive(:start).and_yield
      allow(net_http).to receive(:open_timeout=)
      allow(net_http).to receive(:write_timeout=)
      allow(net_http).to receive(:read_timeout=)
      allow(net_http).to receive(:verify_mode=)
      allow(net_http).to receive(:request).and_return(net_response)

      response = http.get('http://example.com')

      expect(response).to be_a(WSDL::HTTPResponse)
      expect(response.status).to eq(200)
      expect(response.headers).to eq('content-type' => 'text/xml')
      expect(response.body).to eq('raw get!')
    end
  end

  describe '#post' do
    it 'returns an HTTPResponse with status, headers, and body' do
      net_response = instance_double(Net::HTTPOK, code: '200', body: 'raw post!').tap do |r|
        allow(r).to receive(:each_header)
      end

      net_http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(net_http)
      allow(net_http).to receive(:use_ssl=)
      allow(net_http).to receive(:start).and_yield
      allow(net_http).to receive(:open_timeout=)
      allow(net_http).to receive(:write_timeout=)
      allow(net_http).to receive(:read_timeout=)
      allow(net_http).to receive(:verify_mode=)
      allow(net_http).to receive(:request).and_return(net_response)

      response = http.post('http://example.com', { 'Content-Length' => '5' }, 'post request!')

      expect(response).to be_a(WSDL::HTTPResponse)
      expect(response.status).to eq(200)
      expect(response.body).to eq('raw post!')
    end
  end

  describe 'constants' do
    it 'defines DEFAULT_OPEN_TIMEOUT' do
      expect(described_class::DEFAULT_OPEN_TIMEOUT).to eq(30)
    end

    it 'defines DEFAULT_WRITE_TIMEOUT' do
      expect(described_class::DEFAULT_WRITE_TIMEOUT).to eq(60)
    end

    it 'defines DEFAULT_READ_TIMEOUT' do
      expect(described_class::DEFAULT_READ_TIMEOUT).to eq(120)
    end

    it 'defines DEFAULT_REDIRECT_LIMIT' do
      expect(described_class::DEFAULT_REDIRECT_LIMIT).to eq(5)
    end
  end
end
