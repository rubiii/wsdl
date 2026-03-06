# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require 'wsdl'
require 'openssl'

FIXTURE_DIR = File.expand_path('../spec/fixtures', __dir__)

# Shared HTTP mock for file-based WSDL loading
class BenchHTTP
  def client = :bench

  def cache_key = 'bench'

  def get(url)
    WSDL::HTTPResponse.new(status: 200, body: File.read(url))
  end

  def post(_url, _headers, _body)
    WSDL::HTTPResponse.new(status: 200, body: RESPONSE_XML)
  end
end

RESPONSE_XML = File.read(File.join(FIXTURE_DIR, 'security/unsigned_response.xml'))

HTTP = BenchHTTP.new

# Pre-generate a self-signed cert + key for signing benchmarks
SIGN_KEY = OpenSSL::PKey::RSA.generate(2048)
SIGN_CERT = OpenSSL::X509::Certificate.new.tap { |c|
  c.subject = OpenSSL::X509::Name.parse('/CN=bench')
  c.issuer = c.subject
  c.serial = 1
  c.not_before = Time.now - 3600
  c.not_after = Time.now + 3600
  c.public_key = SIGN_KEY.public_key
  c.sign(SIGN_KEY, OpenSSL::Digest.new('SHA256'))
}

SMALL_WSDL = File.join(FIXTURE_DIR, 'wsdl/blz_service.wsdl')
LARGE_WSDL = File.join(FIXTURE_DIR, 'wsdl/economic.wsdl')

puts "Ruby #{RUBY_VERSION} | Nokogiri #{Nokogiri::VERSION}"
puts '-' * 60

# ---------------------------------------------------------------------------
# 1. WSDL Parsing
# ---------------------------------------------------------------------------
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report('parse: small WSDL (blz_service, 88 lines)') do
    WSDL::Parser::Result.parse(SMALL_WSDL, HTTP)
  end

  x.report('parse: large WSDL (economic, 65k lines)') do
    WSDL::Parser::Result.parse(LARGE_WSDL, HTTP)
  end

  x.compare!
end

# ---------------------------------------------------------------------------
# 2. Request Serialization
# ---------------------------------------------------------------------------
small_client = WSDL::Client.new(SMALL_WSDL, http: HTTP, cache: false)
small_service, small_port = small_client.services.first.then { |name, info| [name, info[:ports].keys.first] }
small_op_name = small_client.operations(small_service, small_port).first

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report('serialize: prepare + to_xml') do
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
end

# ---------------------------------------------------------------------------
# 3. WS-Security Signing
# ---------------------------------------------------------------------------
# Build a plain envelope once to sign repeatedly
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
  soap_version: plain_op.soap_version,
  format_xml: true
).to_document

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report('sign: X.509 SHA-256 + Timestamp') do
    config = WSDL::Security::Config.new
    config.timestamp
    config.signature(certificate: SIGN_CERT, private_key: SIGN_KEY)
    WSDL::Security::SecurityHeader.new(config).apply(plain_envelope)
  end

  x.compare!
end

# ---------------------------------------------------------------------------
# 4. Response Parsing
# ---------------------------------------------------------------------------
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report('response: parse body') do
    response = WSDL::Response.new(RESPONSE_XML)
    response.body
  end

  x.compare!
end
