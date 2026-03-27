# frozen_string_literal: true

require 'benchmark'

RSpec.describe 'Response::Parser performance' do
  let(:small_response) { File.read(fixture('security/unsigned_response')) }

  let(:large_response) do
    items = 200.times.map { |i|
      "<item><lineNumber>#{i + 1}</lineNumber>" \
        "<productId>SKU-#{format('%06d', i)}</productId>" \
        "<description>Product item number #{i + 1}</description>" \
        "<quantity>#{i + 1}</quantity>" \
        '<unitPrice>9.99</unitPrice>' \
        '<currency>USD</currency></item>'
    }

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Header/>
        <soap:Body>
          <ns2:GetOrderResponse xmlns:ns2="http://example.com/orders">
            <return>
              <orderId>ORD-123456</orderId>
              <items>#{items.join}</items>
            </return>
          </ns2:GetOrderResponse>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  describe 'small response' do
    it 'parses within acceptable time', :timing do
      parse_time = Benchmark.realtime { WSDL::Response::Parser.parse(small_response) }

      expect(parse_time).to be < 0.01
    end

    it 'stays within allocation budget' do
      allocs = count_allocations { WSDL::Response::Parser.parse(small_response) }

      expect(allocs).to be < 5_000
    end
  end

  describe 'large response (200 items)' do
    it 'parses within acceptable time', :timing do
      parse_time = Benchmark.realtime { WSDL::Response::Parser.parse(large_response) }

      expect(parse_time).to be < 0.5
    end

    it 'stays within allocation budget' do
      allocs = count_allocations { WSDL::Response::Parser.parse(large_response) }

      expect(allocs).to be < 100_000
    end
  end
end
