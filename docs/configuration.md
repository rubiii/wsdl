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

### Configuring the Default HTTPClient

Access the underlying HTTPClient instance through the `http` method:

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl')

# Access the HTTPClient instance
http_client = client.http

# Configure timeouts
http_client.connect_timeout = 30
http_client.send_timeout = 60
http_client.receive_timeout = 60

# Configure SSL
http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
http_client.ssl_config.add_trust_ca('/path/to/ca-bundle.crt')

# Configure proxy
http_client.proxy = 'http://proxy.example.com:8080'

# Configure basic authentication
http_client.set_auth('http://example.com', 'username', 'password')
```

See the [HTTPClient documentation](https://github.com/nahi/httpclient) for all available options.

### Custom HTTP Adapter

You can replace the default HTTP adapter with your own implementation. This allows you to use any HTTP library you prefer (Faraday, Net::HTTP, etc.) without requiring the `httpclient` gem.

A custom adapter must implement:

- `initialize` - Constructor
- `client` - Returns the underlying client instance (for user configuration)
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

By default, the library caches parsed WSDL definitions in memory. This significantly improves performance in multithreaded environments where multiple threads may need to access the same WSDL, avoiding redundant HTTP requests and XML parsing.

### How It Works

When you create a `WSDL` instance, the parsed definition is cached by its location (URL or file path). Subsequent requests for the same WSDL return the cached definition:

``` ruby
# First call fetches and parses the WSDL
client1 = WSDL::Client.new('http://example.com/service?wsdl')

# Second call returns the cached definition - no HTTP request
client2 = WSDL::Client.new('http://example.com/service?wsdl')
```

For inline XML (raw WSDL strings), the cache key is a SHA256 hash of the content.

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

You can provide your own cache implementation (e.g., Redis, Memcached) by implementing the `fetch` method:

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

### Thread Safety

The built-in `WSDL::Cache` is thread-safe. It uses a mutex to ensure that concurrent requests for the same uncached WSDL only trigger a single fetch operation.

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
