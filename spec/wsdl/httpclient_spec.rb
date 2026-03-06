# frozen_string_literal: true

require 'spec_helper'

describe WSDL::HTTPClient do
  subject(:http) { described_class.new }

  describe '#client' do
    it 'returns the HTTPClient instance to configure' do
      expect(http.client).to be_an_instance_of(HTTPClient)
    end
  end

  describe 'secure defaults' do
    describe 'timeouts' do
      it 'sets connect_timeout to 30 seconds' do
        expect(http.client.connect_timeout).to eq(30)
      end

      it 'sets send_timeout to 60 seconds' do
        expect(http.client.send_timeout).to eq(60)
      end

      it 'sets receive_timeout to 120 seconds' do
        expect(http.client.receive_timeout).to eq(120)
      end

      it 'allows customizing timeouts after initialization' do
        http.client.connect_timeout = 10
        http.client.receive_timeout = 300

        expect(http.client.connect_timeout).to eq(10)
        expect(http.client.receive_timeout).to eq(300)
      end
    end

    # httpclient internal types (HTTP::Message, HTTP::Message::Headers)
    # are not easily verifiable-doubled.
    # rubocop:disable RSpec/VerifiedDoubles
    def redirect_response(location)
      header = double('header')
      allow(header).to receive(:[]).with('location').and_return([location])
      double('response', header:)
    end
    # rubocop:enable RSpec/VerifiedDoubles

    describe 'redirect handling' do
      it 'sets follow_redirect_count to 5' do
        expect(http.client.follow_redirect_count).to eq(5)
      end

      it 'allows customizing redirect limit after initialization' do
        http.client.follow_redirect_count = 10

        expect(http.client.follow_redirect_count).to eq(10)
      end

      it 'installs SSRF-safe redirect callback on the underlying client' do
        # Verify the callback is wired up by invoking safe_redirect_uri_callback
        # with a redirect to a private IP, which should raise UnsafeRedirectError.
        uri = URI.parse('http://example.com/service')
        response = redirect_response('http://127.0.0.1/secret')

        expect { http.send(:safe_redirect_uri_callback, uri, response) }
          .to raise_error(WSDL::UnsafeRedirectError)
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
            response = redirect_response(target)

            expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
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
            response = redirect_response(target)

            expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
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
            response = redirect_response(target)
            result = http.send(:safe_redirect_uri_callback, origin_uri, response)

            expect(result.to_s).to eq(target)
          end
        end
      end

      describe 'DNS resolution' do
        it 'blocks hostnames that resolve to private addresses' do
          response = redirect_response('https://evil.example.com/internal')
          allow(Resolv).to receive(:getaddresses).with('evil.example.com').and_return(['127.0.0.1'])

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError)
        end

        it 'blocks when any resolved address is private' do
          response = redirect_response('https://dual.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('dual.example.com').and_return(['93.184.216.34', '10.0.0.1'])

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError)
        end

        it 'allows hostnames that resolve to public addresses' do
          response = redirect_response('https://safe.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('safe.example.com').and_return(['93.184.216.34'])

          result = http.send(:safe_redirect_uri_callback, origin_uri, response)

          expect(result.to_s).to eq('https://safe.example.com/service')
        end

        it 'blocks redirect when DNS resolution times out' do
          response = redirect_response('https://slow-dns.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('slow-dns.example.com') { raise Timeout::Error }

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
        end

        it 'blocks redirect when DNS resolution fails with ResolvError' do
          response = redirect_response('https://nonexistent.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('nonexistent.example.com') { raise Resolv::ResolvError }

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
        end

        it 'blocks redirect when DNS resolution fails with SocketError' do
          response = redirect_response('https://broken-dns.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('broken-dns.example.com') { raise SocketError }

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
        end

        it 'includes the target URL in DNS failure errors' do
          response = redirect_response('https://timeout.example.com/service')
          allow(Resolv).to receive(:getaddresses).with('timeout.example.com') { raise Timeout::Error }

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError) { |error|
              expect(error.target_url).to eq('https://timeout.example.com/service')
            }
        end
      end

      describe 'error attributes' do
        it 'includes the target URL in the error' do
          response = redirect_response('http://127.0.0.1/secret')

          expect { http.send(:safe_redirect_uri_callback, origin_uri, response) }
            .to raise_error(WSDL::UnsafeRedirectError) { |error|
              expect(error.target_url).to eq('http://127.0.0.1/secret')
            }
        end
      end
    end

    describe 'SSL verification' do
      it 'has SSL verification enabled by default' do
        expect(http.ssl_verification_disabled?).to be false
      end

      it 'detects when SSL verification is disabled' do
        http.client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

        expect(http.ssl_verification_disabled?).to be true
      end
    end
  end

  describe 'SSL verification warning' do
    let(:raw_response) { double(status: 200, headers: {}, content: 'response') }
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output) }

    before do
      allow(http.client).to receive(:request).and_return(raw_response)
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
        http.client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
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
        http2.client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        allow(http2.client).to receive(:request).and_return(raw_response)

        http.get('https://example.com')
        http2.get('https://example.com')

        # Each adapter instance should log once, for a total of 2 warnings
        expect(log_output.string.scan('SSL certificate verification is disabled').length).to eq(2)
      end
    end
  end

  describe '#get' do
    it 'returns an HTTPResponse with status, headers, and body' do
      url = 'http://example.com'

      raw_response = double(status: 200, headers: { 'Content-Type' => 'text/xml' }, content: 'raw get!')
      allow(http.client).to receive(:request).with(:get, url, nil, nil, {}).and_return(raw_response)

      response = http.get(url)

      expect(response).to be_a(WSDL::HTTPResponse)
      expect(response.status).to eq(200)
      expect(response.headers).to eq('Content-Type' => 'text/xml')
      expect(response.body).to eq('raw get!')
    end
  end

  describe '#post' do
    it 'returns an HTTPResponse with status, headers, and body' do
      url = 'http://example.com'
      body = 'post request!'
      headers = { 'Content-Length' => 5 }

      raw_response = double(status: 200, headers: {}, content: 'raw post!')
      allow(http.client).to receive(:request).with(:post, url, nil, body, headers).and_return(raw_response)

      response = http.post(url, headers, body)

      expect(response).to be_a(WSDL::HTTPResponse)
      expect(response.status).to eq(200)
      expect(response.body).to eq('raw post!')
    end
  end

  describe 'constants' do
    it 'defines DEFAULT_CONNECT_TIMEOUT' do
      expect(described_class::DEFAULT_CONNECT_TIMEOUT).to eq(30)
    end

    it 'defines DEFAULT_SEND_TIMEOUT' do
      expect(described_class::DEFAULT_SEND_TIMEOUT).to eq(60)
    end

    it 'defines DEFAULT_RECEIVE_TIMEOUT' do
      expect(described_class::DEFAULT_RECEIVE_TIMEOUT).to eq(120)
    end

    it 'defines DEFAULT_REDIRECT_LIMIT' do
      expect(described_class::DEFAULT_REDIRECT_LIMIT).to eq(5)
    end

    it 'defines DNS_RESOLUTION_TIMEOUT' do
      expect(described_class::DNS_RESOLUTION_TIMEOUT).to eq(5)
    end
  end
end
