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

    describe 'redirect handling' do
      it 'sets follow_redirect_count to 5' do
        expect(http.client.follow_redirect_count).to eq(5)
      end

      it 'allows customizing redirect limit after initialization' do
        http.client.follow_redirect_count = 10

        expect(http.client.follow_redirect_count).to eq(10)
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
    let(:response) { double(content: 'response') }
    let(:logger) { Logging.logger[http] }

    before do
      allow(http.client).to receive(:request).and_return(response)
      allow(logger).to receive(:warn)
    end

    context 'when SSL verification is enabled' do
      it 'does not log a warning on GET' do
        http.get('https://example.com')

        expect(logger).not_to have_received(:warn)
      end

      it 'does not log a warning on POST' do
        http.post('https://example.com', {}, 'body')

        expect(logger).not_to have_received(:warn)
      end
    end

    context 'when SSL verification is disabled' do
      before do
        http.client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      it 'logs a warning on GET' do
        http.get('https://example.com')

        expect(logger).to have_received(:warn).with(/SSL certificate verification is disabled/)
      end

      it 'logs a warning on POST' do
        http.post('https://example.com', {}, 'body')

        expect(logger).to have_received(:warn).with(/SSL certificate verification is disabled/)
      end

      it 'mentions man-in-the-middle attacks in the warning' do
        http.get('https://example.com')

        expect(logger).to have_received(:warn).with(/man-in-the-middle/)
      end

      it 'only logs the warning once per adapter instance' do
        http.get('https://example.com')
        http.get('https://example.com')
        http.post('https://example.com', {}, 'body')

        expect(logger).to have_received(:warn).once
      end

      it 'logs again for a new adapter instance' do
        http2 = described_class.new
        http2.client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        allow(http2.client).to receive(:request).and_return(response)

        # Both adapters use the same class-based logger, so we check
        # that each instance logs once (total of 2 warnings)
        http.get('https://example.com')
        http2.get('https://example.com')

        # Each adapter instance should log once, for a total of 2 warnings
        expect(logger).to have_received(:warn).twice
      end
    end
  end

  describe '#get' do
    it 'executes an HTTP GET request and returns the raw response' do
      url = 'http://example.com'

      response = double(content: 'raw get!')
      allow(http.client).to receive(:request).with(:get, url, nil, nil, {}).and_return(response)

      raw_response = http.get(url)

      expect(raw_response).to eq('raw get!')
    end
  end

  describe '#post' do
    it 'executes an HTTP POST request and returns the raw response' do
      url = 'http://example.com'
      body = 'post request!'
      headers = { 'Content-Length' => 5 }

      response = double(content: 'raw post!')
      allow(http.client).to receive(:request).with(:post, url, nil, body, headers).and_return(response)

      raw_response = http.post(url, headers, body)

      expect(raw_response).to eq('raw post!')
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
  end
end
