# frozen_string_literal: true

require 'spec_helper'

describe WSDL::HTTPAdapter do
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

  describe 'redirect SSRF protection' do
    let(:origin_uri) { URI.parse('https://example.com/service?wsdl') }

    describe 'blocks private/reserved IP address literals' do
      %w[
        http://127.0.0.1/secret
        http://10.0.0.1/internal
        http://172.16.0.1/internal
        http://192.168.1.1/internal
        http://169.254.169.254/latest/meta-data/
        http://100.64.0.1/internal
        http://0.0.0.1/internal
      ].each do |target|
        it "blocks redirect to #{target}" do
          uri = URI.parse(target)

          expect { http.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    describe 'blocks private IPv6 address literals' do
      %w[
        http://[::1]/secret
        http://[fc00::1]/internal
        http://[fe80::1]/internal
      ].each do |target|
        it "blocks redirect to #{target}" do
          uri = URI.parse(target)

          expect { http.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    describe 'allows public IP addresses' do
      %w[
        https://93.184.216.34/service
        https://8.8.8.8/service
        https://203.0.113.1/service
      ].each do |target|
        it "allows redirect to #{target}" do
          uri = URI.parse(target)

          expect { http.send(:validate_redirect_target!, uri) }.not_to raise_error
        end
      end
    end

    describe 'DNS resolution' do
      it 'blocks hostnames that resolve to private addresses' do
        uri = URI.parse('https://evil.example.com/internal')
        allow(Resolv).to receive(:getaddresses).with('evil.example.com').and_return(['127.0.0.1'])

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError)
      end

      it 'blocks when any resolved address is private' do
        uri = URI.parse('https://dual.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('dual.example.com').and_return(['93.184.216.34', '10.0.0.1'])

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError)
      end

      it 'allows hostnames that resolve to public addresses' do
        uri = URI.parse('https://safe.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('safe.example.com').and_return(['93.184.216.34'])

        expect { http.send(:validate_redirect_target!, uri) }.not_to raise_error
      end

      it 'blocks redirect when DNS resolution times out' do
        uri = URI.parse('https://slow-dns.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('slow-dns.example.com') { raise Timeout::Error }

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks redirect when DNS resolution fails with ResolvError' do
        uri = URI.parse('https://nonexistent.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('nonexistent.example.com') { raise Resolv::ResolvError }

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks redirect when DNS resolution fails with SocketError' do
        uri = URI.parse('https://broken-dns.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('broken-dns.example.com') { raise SocketError }

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'includes the target URL in DNS failure errors' do
        uri = URI.parse('https://timeout.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('timeout.example.com') { raise Timeout::Error }

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError) { |error|
            expect(error.target_url).to eq('https://timeout.example.com/service')
          }
      end
    end

    describe 'error attributes' do
      it 'includes the target URL in the error' do
        uri = URI.parse('http://127.0.0.1/secret')

        expect { http.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError) { |error|
            expect(error.target_url).to eq('http://127.0.0.1/secret')
          }
      end
    end
  end

  describe 'HTTPS to HTTP downgrade protection' do
    it 'blocks HTTPS to HTTP downgrades' do
      original = URI.parse('https://example.com/service')
      target = URI.parse('http://example.com/service')

      expect { http.send(:validate_redirect_scheme!, original, target) }
        .to raise_error(WSDL::UnsafeRedirectError, /HTTPS to HTTP downgrade/)
    end

    it 'allows HTTP to HTTP redirects' do
      original = URI.parse('http://example.com/service')
      target = URI.parse('http://other.example.com/service')

      expect { http.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
    end

    it 'allows HTTPS to HTTPS redirects' do
      original = URI.parse('https://example.com/service')
      target = URI.parse('https://other.example.com/service')

      expect { http.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
    end

    it 'allows HTTP to HTTPS upgrades' do
      original = URI.parse('http://example.com/service')
      target = URI.parse('https://example.com/service')

      expect { http.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
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

    it 'treats a redirect without Location header as a redirect to the same URI' do
      redirect_response = instance_double(Net::HTTPFound, code: '302', body: '').tap do |r|
        allow(r).to receive(:each_header).and_yield('content-type', 'text/html')
      end

      allow(net_http).to receive(:request).and_return(redirect_response)

      http.config.max_redirects = 1

      expect { http.get('https://example.com/start') }
        .to raise_error(WSDL::TooManyRedirectsError)
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

    it 'defines DNS_RESOLUTION_TIMEOUT' do
      expect(described_class::DNS_RESOLUTION_TIMEOUT).to eq(5)
    end
  end
end
