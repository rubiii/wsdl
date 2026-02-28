# frozen_string_literal: true

require 'spec_helper'

describe WSDL::HTTPClient do
  subject(:http) { described_class.new }

  describe '#client' do
    it 'returns the HTTPClient instance to configure' do
      expect(http.client).to be_an_instance_of(HTTPClient)
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
end
