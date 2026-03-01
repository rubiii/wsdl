# WSDL

WSDL toolkit for Ruby. Turn WSDL documents into inspectable services and callable operations.

## Installation

```
$ gem install wsdl
```

or add it to your Gemfile:

``` ruby
gem 'wsdl'
gem 'httpclient'  # optional: required for default HTTP adapter
```

> **Note:** The `httpclient` gem is optional. If you prefer a different HTTP library (like Faraday), you can configure a custom adapter instead. See the [configuration docs](docs/configuration.md#http-adapter) for details.

## Usage

``` ruby
require 'wsdl'

# Load a WSDL document
client = WSDL::Client.new('http://example.com/service?wsdl')

# Inspect available services
client.services
# => { 'ServiceName' => { ports: { 'PortName' => { type: '...', location: '...' } } } }

# List operations for a service and port
client.operations('ServiceName', 'PortName')
# => ['Operation1', 'Operation2', ...]

# Get an operation
operation = client.operation('ServiceName', 'PortName', 'Operation1')

# Check the example body structure
operation.example_body
# => { Operation1: { Parameter1: 'string', Parameter2: 'int' } }

# Set the body
operation.body = { Operation1: { Parameter1: 'value', Parameter2: 42 } }

# Optionally, sign requests with WS-Security (see docs/ws-security.md)
operation.security.timestamp
operation.security.signature(
  certificate: File.read('cert.pem'),
  private_key: File.read('key.pem')
)

# Call the operation
response = operation.call

# Access the response
response.body   # => parsed Hash
response.raw    # => raw XML string
```

## Documentation

See the [docs](docs/) folder for more detailed documentation.

## License

Released under the [MIT License](MIT-LICENSE).
