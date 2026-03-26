# frozen_string_literal: true

module SpecSupport
  class HTTPMock
    class MockError < StandardError
    end

    def initialize
      @fakes = {}
    end

    def config
      :mock_config
    end

    def cache_key
      self.class.name
    end

    def get(url)
      entry = @fakes[url] or raise_mock_error!(:get, url)
      WSDL::HTTP::Response.new(status: entry[:status], body: entry[:body])
    end

    def post(url, _headers, _body)
      entry = @fakes[url] or raise_mock_error!(:post, url)
      WSDL::HTTP::Response.new(status: entry[:status], body: entry[:body])
    end

    def fake_request(url, fixture = nil, status: 200)
      body = fixture ? load_fixture(fixture) : ''
      @fakes[url] = { status:, body: }
    end

    private

    def load_fixture(fixture)
      File.read Fixture.path(fixture)
    end

    def raise_mock_error!(method, url)
      raise MockError, "Unmocked HTTP #{method.to_s.upcase} request to #{url.inspect}"
    end
  end

  def http_mock
    @http_mock ||= HTTPMock.new
  end
end
