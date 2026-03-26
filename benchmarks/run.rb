# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require 'json'
require 'wsdl'
require 'openssl'

FIXTURE_DIR = File.expand_path('../spec/fixtures', __dir__)

# Shared HTTP mock for file-based WSDL loading
class BenchHTTP
  def client = :bench

  def cache_key = 'bench'

  def get(url)
    WSDL::HTTP::Response.new(status: 200, body: File.read(url))
  end

  def post(_url, _headers, _body)
    WSDL::HTTP::Response.new(status: 200, body: SMALL_RESPONSE_XML)
  end
end

SMALL_RESPONSE_XML = File.read(File.join(FIXTURE_DIR, 'security/unsigned_response.xml'))

HTTP = BenchHTTP.new

# Pre-generate a self-signed cert + key for signing/verification benchmarks
SIGN_KEY = OpenSSL::PKey::RSA.generate(2048)
SIGN_CERT = OpenSSL::X509::Certificate.new.tap { |c|
  c.version = 2
  c.subject = OpenSSL::X509::Name.new([%w[CN Benchmark]])
  c.issuer = c.subject
  c.serial = 1
  c.not_before = Time.now - 3600
  c.not_after = Time.now + 3600
  c.public_key = SIGN_KEY.public_key
  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = c
  ef.issuer_certificate = c
  c.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))
  c.sign(SIGN_KEY, OpenSSL::Digest.new('SHA256'))
}

SMALL_WSDL = File.join(FIXTURE_DIR, 'wsdl/blz_service.wsdl')
LARGE_WSDL = File.join(FIXTURE_DIR, 'wsdl/economic.wsdl')

# Build a realistic large SOAP response (~200 order line items)
def build_large_response_items(count)
  count.times.map { |i|
    "<item><lineNumber>#{i + 1}</lineNumber>" \
      "<productId>SKU-#{format('%06d', i)}</productId>" \
      "<description>Product item number #{i + 1} with a reasonably long description</description>" \
      "<quantity>#{rand(1..100)}</quantity>" \
      "<unitPrice>#{format('%.2f', rand(1.0..999.99))}</unitPrice>" \
      '<currency>USD</currency><taxRate>0.08</taxRate>' \
      "<warehouse>WH-#{%w[EAST WEST CENTRAL SOUTH].sample}</warehouse></item>"
  }
end

def build_large_response(items: 200)
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header/>
      <soap:Body>
        <ns2:GetOrderResponse xmlns:ns2="http://example.com/orders">
          <return>
            <orderId>ORD-123456</orderId>
            <customerName>Jane Doe</customerName>
            <orderDate>2025-03-01T10:30:00Z</orderDate>
            <status>shipped</status>
            <items>#{build_large_response_items(items).join}</items>
            <totalAmount>42567.89</totalAmount>
          </return>
        </ns2:GetOrderResponse>
      </soap:Body>
    </soap:Envelope>
  XML
end

LARGE_RESPONSE_XML = build_large_response

# Build a signed envelope for the verification benchmark
def build_signed_envelope
  envelope = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
      <soap:Header/>
      <soap:Body xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" wsu:Id="Body-bench">
        <GetUserResponse xmlns="http://example.com/users">
          <User><Name>John Doe</Name><Email>john@example.com</Email></User>
        </GetUserResponse>
      </soap:Body>
    </soap:Envelope>
  XML

  config = WSDL::Security::Config.new
  config.timestamp
  config.signature(certificate: SIGN_CERT, private_key: SIGN_KEY)
  WSDL::Security::SecurityHeader.new(config).apply(envelope)
end

SIGNED_RESPONSE_XML = build_signed_envelope

puts "Ruby #{RUBY_VERSION} | Nokogiri #{Nokogiri::VERSION}"
puts '-' * 60

# ---------------------------------------------------------------------------
# 1. WSDL Parsing
# ---------------------------------------------------------------------------
parsing_report = Benchmark.ips { |x|
  x.config(warmup: 2, time: 5)

  x.report('parse: small WSDL (blz_service, 88 lines)') do
    WSDL::Parser::Result.parse(SMALL_WSDL, HTTP)
  end

  x.report('parse: large WSDL (economic, 65k lines)') do
    WSDL::Parser::Result.parse(LARGE_WSDL, HTTP)
  end

  x.compare!
}

# ---------------------------------------------------------------------------
# 2. Request Building (operation + prepare + serialize)
# ---------------------------------------------------------------------------
small_client = WSDL::Client.new(SMALL_WSDL, http: HTTP, cache: false)
small_service, small_port = small_client.services.first.then { |name, info| [name, info[:ports].keys.first] }
small_op_name = small_client.operations(small_service, small_port).first

request_report = Benchmark.ips { |x|
  x.config(warmup: 2, time: 5)

  x.report('request: build + serialize') do
    op = small_client.operation(small_service, small_port, small_op_name)
    op.prepare do
      body do
        tag('getBank') do
          tag('blz', '70070010')
        end
      end
    end
    op.to_xml
  end

  x.compare!
}

# ---------------------------------------------------------------------------
# 3. WS-Security Signing
# ---------------------------------------------------------------------------
plain_op = small_client.operation(small_service, small_port, small_op_name)
plain_op.prepare do
  body do
    tag('getBank') do
      tag('blz', '70070010')
    end
  end
end
plain_envelope = WSDL::Request::Serializer.new(
  document: plain_op.send(:prepare_serializable_document, plain_op.instance_variable_get(:@request_document)),
  soap_version: plain_op.soap_version
).to_document

signing_report = Benchmark.ips { |x|
  x.config(warmup: 2, time: 5)

  x.report('sign: X.509 SHA-256 + Timestamp') do
    config = WSDL::Security::Config.new
    config.timestamp
    config.signature(certificate: SIGN_CERT, private_key: SIGN_KEY)
    WSDL::Security::SecurityHeader.new(config).apply(plain_envelope)
  end

  x.compare!
}

# ---------------------------------------------------------------------------
# 4. WS-Security Verification
# ---------------------------------------------------------------------------
verification_report = Benchmark.ips { |x|
  x.config(warmup: 2, time: 5)

  x.report('verify: signature + timestamp') do
    verifier = WSDL::Security::Verifier.new(SIGNED_RESPONSE_XML)
    verifier.valid?
  end

  x.compare!
}

# ---------------------------------------------------------------------------
# 5. Response Parsing
# ---------------------------------------------------------------------------
response_report = Benchmark.ips { |x|
  x.config(warmup: 2, time: 5)

  x.report('response: parse small (15 lines)') do
    WSDL::Response.new(http_response: WSDL::HTTP::Response.new(status: 200, body: SMALL_RESPONSE_XML)).body
  end

  x.report('response: parse large (200 items)') do
    WSDL::Response.new(http_response: WSDL::HTTP::Response.new(status: 200, body: LARGE_RESPONSE_XML)).body
  end

  x.compare!
}

# ---------------------------------------------------------------------------
# JSON output for CI regression tracking (github-action-benchmark format)
# ---------------------------------------------------------------------------
output_path = ENV.fetch('BENCHMARK_OUTPUT', nil)

if output_path
  reports = [parsing_report, request_report, signing_report, verification_report, response_report]
  json_data = reports.flat_map { |report|
    report.entries.map { |entry|
      {
        name: entry.label,
        unit: 'i/s',
        value: entry.ips.round(2),
        range: "± #{entry.error_percentage.round(1)}%"
      }
    }
  }

  File.write(output_path, JSON.pretty_generate(json_data))
  puts
  puts "Benchmark JSON written to #{output_path}"
end
