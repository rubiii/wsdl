# Configuration

This guide covers the configuration options available in the WSDL library.

## HTTP Adapter

By default, the library uses `HTTPClient` to make HTTP requests. You can access and configure it, or replace it entirely with a custom adapter.

### Configuring the Default HTTPClient

Access the underlying HTTPClient instance through the `http` method:

``` ruby
client = WSDL.new('http://example.com/service?wsdl')

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

You can replace the default HTTP adapter with your own implementation. A custom adapter must implement:

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
client = WSDL.new('http://example.com/service?wsdl')
```

#### Setting the Custom Adapter Per-Client

``` ruby
http = MyHTTPAdapter.new
client = WSDL.new('http://example.com/service?wsdl', http)
```

#### Resetting to Default

``` ruby
WSDL.http_adapter = nil
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

## Logging

The library uses the [logging](https://github.com/TwP/logging) gem. Enable debug logging to troubleshoot issues:

``` ruby
require 'wsdl'
require 'logging'

# Enable logging for WSDL classes
logger = Logging.logger['WSDL::Importer']
logger.add_appenders(Logging.appenders.stdout)
logger.level = :debug

client = WSDL.new('http://example.com/service?wsdl')
# Debug output will show WSDL/schema import progress
```

### Available Loggers

- `WSDL::Importer` - WSDL and schema import process
- `WSDL::Envelope` - Request envelope building
- `WSDL::Message` - Message part building
- `WSDL::XS` - XML Schema type resolution
- `WSDL::XML::ElementBuilder` - Element building

## Environment Variables

Set the `DEBUG` environment variable to enable logging for a specific class:

``` bash
DEBUG=WSDL::Importer ruby my_script.rb
```

This requires the logging setup in your code:

``` ruby
if logger_to_enable = ENV['DEBUG']
  logger = Logging.logger[logger_to_enable]
  logger.add_appenders(Logging.appenders.stdout)
  logger.level = :debug
end
```
