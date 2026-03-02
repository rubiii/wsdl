# Configuration

This guide covers the configuration options available in the WSDL library.

## HTTP Adapter

By default, the library uses `HTTPClient` to make HTTP requests. You can access and configure it, or replace it entirely with a custom adapter.

> **Note:** The `httpclient` gem is an optional dependency. If you want to use the default HTTPClient adapter, add it to your Gemfile:
>
> ``` ruby
> gem 'httpclient'
> ```
>
> If you use a custom adapter (like Faraday), you don't need to install httpclient at all.

### Secure Defaults

The default HTTPClient adapter applies secure defaults out of the box:

| Setting | Default | Description |
|---------|---------|-------------|
| `connect_timeout` | 30 seconds | Maximum time to establish a connection |
| `send_timeout` | 60 seconds | Maximum time to send request data |
| `receive_timeout` | 120 seconds | Maximum time to receive response data |
| `follow_redirect_count` | 5 | Maximum redirects to follow |
| SSL verification | Enabled | Verifies server certificates (VERIFY_PEER) |

These defaults prevent indefinite hangs, redirect loops, and man-in-the-middle attacks.

### Configuring the Default HTTPClient

Access the underlying HTTPClient instance through the `http` method:

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl')

# Access the HTTPClient instance
http_client = client.http

# Customize timeouts (overriding secure defaults)
http_client.connect_timeout = 10   # Shorter timeout
http_client.receive_timeout = 300  # Longer timeout for slow services

# Configure SSL
http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
http_client.ssl_config.add_trust_ca('/path/to/ca-bundle.crt')

# Configure proxy
http_client.proxy = 'http://proxy.example.com:8080'

# Configure basic authentication
http_client.set_auth('http://example.com', 'username', 'password')
```

See the [HTTPClient documentation](https://github.com/nahi/httpclient) for all available options.

### SSL/TLS Security

SSL/TLS verification is **enabled by default** and should remain enabled in production. The library verifies server certificates against your system's trusted CA bundle.

#### Why SSL Verification Matters

SSL verification ensures you're communicating with the intended server and not an attacker performing a man-in-the-middle attack. Disabling verification exposes your application to:

- **Credential theft** — Attackers can intercept usernames, passwords, and API keys
- **Data tampering** — SOAP messages can be modified in transit
- **Data exfiltration** — Sensitive response data can be captured

#### Custom CA Certificates

If your SOAP service uses a certificate signed by an internal CA or a CA not in your system's trust store:

``` ruby
client = WSDL::Client.new('https://example.com/service?wsdl')

# Add a single CA certificate
client.http.ssl_config.add_trust_ca('/path/to/internal-ca.crt')

# Or add a directory of CA certificates
client.http.ssl_config.add_trust_ca('/path/to/ca-certs/')
```

#### Client Certificate Authentication (Mutual TLS)

Some services require client certificates for authentication:

``` ruby
client = WSDL::Client.new('https://example.com/service?wsdl')

# Using separate certificate and key files
client.http.ssl_config.set_client_cert_file(
  '/path/to/client.crt',
  '/path/to/client.key'
)

# With an encrypted private key
client.http.ssl_config.set_client_cert_file(
  '/path/to/client.crt',
  '/path/to/client.key',
  'key-passphrase'
)
```

#### Troubleshooting SSL Errors

Common SSL errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `certificate verify failed` | Server certificate not trusted | Add the CA certificate with `add_trust_ca` |
| `self signed certificate` | Self-signed server certificate | Add the server's certificate to trust store |
| `certificate has expired` | Server certificate expired | Contact the service administrator |
| `hostname mismatch` | Certificate doesn't match URL | Use the correct hostname or check certificate |

#### Development Only: Disabling SSL Verification

> ⚠️ **Security Warning:** Never disable SSL verification in production. This completely removes protection against man-in-the-middle attacks and should only be used for local development or testing.

If you must disable verification for development with self-signed certificates:

``` ruby
# DEVELOPMENT ONLY - Never use in production!
client = WSDL::Client.new('https://localhost/service?wsdl')
client.http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
```

> **Note:** When SSL verification is disabled, the library logs a warning on the first request:
> `SSL certificate verification is disabled. This makes connections vulnerable to man-in-the-middle attacks.`

A safer alternative for development is to add your development CA to the trust store:

``` ruby
# Safer: Trust your development CA
client.http.ssl_config.add_trust_ca('/path/to/dev-ca.crt')
```

### Custom HTTP Adapter

You can replace the default HTTP adapter with your own implementation. This allows you to use any HTTP library you prefer (Faraday, Net::HTTP, etc.) without requiring the `httpclient` gem.

A custom adapter must implement:

- `initialize` - Constructor
- `client` - Returns the underlying client instance (for user configuration)
- `cache_key` - Returns a stable String identifying parser-affecting adapter behavior
- `get(url)` - Performs an HTTP GET request, returns the response body as a String
- `post(url, headers, body)` - Performs an HTTP POST request, returns the response body as a String

#### Example: Custom Adapter

``` ruby
class MyHTTPAdapter
  def initialize
    @client = Faraday.new do |f|
      f.adapter Faraday.default_adapter
    end
  end

  # Returns the client instance for configuration
  def client
    @client
  end

  # Stable identity used for parser cache partitioning
  def cache_key
    'my-http-adapter:v1'
  end

  # GET request - used for fetching WSDL documents
  def get(url)
    response = @client.get(url)
    response.body
  end

  # POST request - used for SOAP calls
  def post(url, headers, body)
    response = @client.post(url) do |req|
      req.headers = headers
      req.body = body
    end
    response.body
  end
end
```

#### Setting the Custom Adapter Globally

``` ruby
WSDL.http_adapter = MyHTTPAdapter

# All new clients will use the custom adapter
client = WSDL::Client.new('http://example.com/service?wsdl')
```

#### Setting the Custom Adapter Per-Client

``` ruby
http = MyHTTPAdapter.new
client = WSDL::Client.new('http://example.com/service?wsdl', http)
```

#### Resetting to Default

``` ruby
WSDL.http_adapter = nil
```

## Caching

By default, the library caches parsed WSDL definitions in memory. This significantly improves performance in
multithreaded environments where multiple threads may need to access the same WSDL, avoiding redundant HTTP
requests and XML parsing.

### How It Works

When you create a `WSDL::Client`, parser results are cached by a composite parse profile key. The key includes:

- WSDL source identity (URL/file path/inline XML content hash)
- `sandbox_paths`
- `limits`
- `reject_doctype`
- `schema_imports`
- HTTP adapter identity

Subsequent clients with the same parse profile return the cached definition:

``` ruby
# First call fetches and parses the WSDL
client1 = WSDL::Client.new('http://example.com/service?wsdl')

# Second call returns the cached definition - no HTTP request
client2 = WSDL::Client.new('http://example.com/service?wsdl')
```

Inline XML is represented by a SHA256 content hash inside the parse profile key.

### Schema Import Policy

Schema import failures are configurable per client:

``` ruby
# Default: log and skip non-security schema import failures
client = WSDL::Client.new('http://example.com/service?wsdl', schema_imports: :best_effort)

# Strict: raise non-security schema import failures
client = WSDL::Client.new('http://example.com/service?wsdl', schema_imports: :strict)
```

Why `:best_effort` is the default:

- Many production WSDLs reference optional or environment-specific schemas
- Skipping recoverable import failures keeps service metadata usable
- Fatal security/safety failures still raise immediately

Policy behavior:

- `:best_effort` — non-security schema import failures are logged and skipped
- `:strict` — non-security schema import failures are raised as `WSDL::SchemaImportError`
- Fatal errors (`WSDL::FatalError` subclasses, such as `WSDL::PathRestrictionError`) are always raised

### Configuring the Cache

#### Using a Custom Cache with TTL

``` ruby
# Create a cache with 1-hour TTL
WSDL.cache = WSDL::Cache.new(ttl: 3600)
```

#### Clearing the Cache

``` ruby
WSDL.cache.clear
```

#### Disabling Caching Globally

``` ruby
WSDL.cache = nil
```

#### Disabling Caching Per-Client

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl', cache: nil)
```

#### Using a Separate Cache Instance

``` ruby
my_cache = WSDL::Cache.new(ttl: 1800)
client = WSDL::Client.new('http://example.com/service?wsdl', cache: my_cache)
```

### Custom Cache Implementation

You can provide your own cache implementation (e.g., Redis, Memcached) by implementing the `fetch` method.
The incoming `key` is already a stable parser-profile key string:

``` ruby
class RedisCache
  def initialize(redis, ttl: nil)
    @redis = redis
    @ttl = ttl
  end

  def fetch(key)
    cached = @redis.get(cache_key(key))
    return Marshal.load(cached) if cached

    value = yield
    if @ttl
      @redis.setex(cache_key(key), @ttl, Marshal.dump(value))
    else
      @redis.set(cache_key(key), Marshal.dump(value))
    end
    value
  end

  def clear
    @redis.keys('wsdl:*').each { |k| @redis.del(k) }
  end

  private

  def cache_key(key)
    "wsdl:#{Digest::SHA256.hexdigest(key)}"
  end
end

# Use the custom cache
WSDL.cache = RedisCache.new(Redis.new, ttl: 3600)
```

### Custom Adapter Cache Identity

When you pass explicit HTTP adapter instances, the cache key includes adapter identity to avoid mixing parser
results from incompatible adapter behavior.

If equivalent adapter instances should share cache entries, implement `cache_key` on your adapter:

``` ruby
class MyHTTPAdapter
  attr_reader :client

  def initialize(timeout: 30)
    @timeout = timeout
    @client = Faraday.new do |f|
      f.options.timeout = timeout
    end
  end

  # Should return a stable fingerprint for parser-affecting behavior.
  def cache_key
    "my-http-adapter:v1:timeout=#{@timeout}"
  end

  def get(url)
    @client.get(url).body
  end

  def post(url, headers, body)
    @client.post(url, body, headers).body
  end
end
```

### Thread Safety

The built-in `WSDL::Cache` is thread-safe. It uses a mutex to ensure that concurrent requests for the same uncached WSDL only trigger a single fetch operation.

## Resource Limits

The library enforces configurable resource limits to prevent denial-of-service attacks from malformed or malicious WSDL documents. These limits protect against excessive memory consumption, infinite loops, and other resource exhaustion attacks.

### Default Limits

| Limit | Default | Description |
|-------|---------|-------------|
| `max_document_size` | 10 MB | Maximum size for a single WSDL or schema document |
| `max_total_download_size` | 50 MB | Maximum cumulative bytes downloaded across all documents |
| `max_schemas` | 50 | Maximum number of schema definitions allowed |
| `max_elements_per_type` | 500 | Maximum child elements in a complex type |
| `max_attributes_per_element` | 100 | Maximum attributes on an XML element |
| `max_type_nesting_depth` | 50 | Maximum depth of type inheritance/nesting |

### Configuring Limits Globally

``` ruby
# Create custom limits
WSDL.limits = WSDL::Limits.new(
  max_document_size: 20 * 1024 * 1024,  # 20 MB
  max_schemas: 100
)

# Or modify specific limits from defaults
WSDL.limits = WSDL.limits.with(max_schemas: 100)
```

### Configuring Limits Per-Client

``` ruby
# Create custom limits for a specific client
custom_limits = WSDL::Limits.new(max_schemas: 100, max_document_size: 20 * 1024 * 1024)
client = WSDL::Client.new('http://example.com/service?wsdl', limits: custom_limits)

# Or derive from global limits
custom_limits = WSDL.limits.with(max_schemas: 100)
client = WSDL::Client.new('http://example.com/service?wsdl', limits: custom_limits)
```

### Disabling Specific Limits

Set a limit to `nil` to disable it:

``` ruby
# Disable schema count limit (not recommended)
unlimited_schemas = WSDL.limits.with(max_schemas: nil)
client = WSDL::Client.new('http://example.com/service?wsdl', limits: unlimited_schemas)
```

### Handling Limit Errors

When a limit is exceeded, `WSDL::ResourceLimitError` is raised with details:

``` ruby
begin
  client = WSDL::Client.new('http://example.com/huge.wsdl')
rescue WSDL::ResourceLimitError => e
  puts "Limit exceeded: #{e.limit_name}"
  puts "Limit value: #{e.limit_value}"
  puts "Actual value: #{e.actual_value}"
  puts "Message: #{e.message}"
end
```

### Inspecting Limits

``` ruby
puts WSDL.limits.inspect
# => #<WSDL::Limits max_document_size=10MB max_total_download_size=50MB max_schemas=50 ...>

puts WSDL.limits.to_h
# => {:max_document_size=>10485760, :max_total_download_size=>52428800, ...}
```

## Operation Defaults

Operation settings can be configured after obtaining an operation object.

### Endpoint

Override the endpoint specified in the WSDL:

``` ruby
operation = client.operation('Service', 'Port', 'Operation')
operation.endpoint = 'http://staging.example.com/service'
```

### SOAP Version

Force a specific SOAP version:

``` ruby
operation.soap_version = '1.1'  # or '1.2'
```

### SOAP Action

Override the SOAPAction HTTP header:

``` ruby
operation.soap_action = 'http://example.com/MyCustomAction'
```

### Character Encoding

Change the character encoding (default: UTF-8):

``` ruby
operation.encoding = 'ISO-8859-1'
```

### HTTP Headers

Completely override the HTTP headers:

``` ruby
operation.http_headers = {
  'Content-Type' => 'text/xml;charset=UTF-8',
  'SOAPAction' => '"http://example.com/Action"',
  'Authorization' => 'Bearer token123'
}
```

## XML Formatting

By default, the library generates XML with indentation and line breaks for readability. Some SOAP servers (e.g., Microsoft Dynamics NAV / Navision) are sensitive to whitespace in the XML body and may reject requests that contain formatting.

### Disabling Pretty Printing

To generate compact XML without indentation or line breaks, set `pretty_print: false` when creating the client:

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl', pretty_print: false)
```

All operations created from this client will generate compact XML:

``` ruby
operation = client.operation('Service', 'Port', 'Operation')
operation.body = { GetOrder: { orderId: 123 } }

puts operation.build
# Output is a single line with no indentation
```

### Per-Operation Override

You can also change the setting on individual operations:

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl')

operation = client.operation('Service', 'Port', 'Operation')
operation.pretty_print = false  # Override for this operation only
```

### Comparison

With `pretty_print: true` (default):

``` xml
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Header>
  </env:Header>
  <env:Body>
    <ns:GetOrder xmlns:ns="http://example.com/">
      <ns:orderId>123</ns:orderId>
    </ns:GetOrder>
  </env:Body>
</env:Envelope>
```

With `pretty_print: false`:

``` xml
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Header></env:Header><env:Body><ns:GetOrder xmlns:ns="http://example.com/"><ns:orderId>123</ns:orderId></ns:GetOrder></env:Body></env:Envelope>
```

## Logging

The library uses the [logging](https://github.com/TwP/logging) gem. Enable debug logging to troubleshoot issues:

``` ruby
require 'wsdl'
require 'logging'

# Enable logging for WSDL classes
logger = Logging.logger['WSDL::Parser::Importer']
logger.add_appenders(Logging.appenders.stdout)
logger.level = :debug

client = WSDL::Client.new('http://example.com/service?wsdl')
# Debug output will show WSDL/schema import progress
```

### Available Loggers

- `WSDL::Parser::Importer` - WSDL and schema import process
- `WSDL::Builder::Envelope` - Request envelope building
- `WSDL::Builder::Message` - Message part building
- `WSDL::Schema` - XML Schema type resolution
- `WSDL::XML::ElementBuilder` - Element building

## Environment Variables

Set the `DEBUG` environment variable to enable logging for a specific class:

``` bash
DEBUG=WSDL::Parser::Importer ruby my_script.rb
```

This requires the logging setup in your code:

``` ruby
if logger_to_enable = ENV['DEBUG']
  logger = Logging.logger[logger_to_enable]
  logger.add_appenders(Logging.appenders.stdout)
  logger.level = :debug
end
```
