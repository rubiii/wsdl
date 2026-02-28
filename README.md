# WSDL

WSDL toolkit for Ruby. Turn WSDL documents into inspectable services and callable operations.

## Installation

```
$ gem install wsdl
```

or add it to your Gemfile:

``` ruby
gem 'wsdl'
```

## Usage

``` ruby
require 'wsdl'

# Load a WSDL document
client = WSDL.new('http://example.com/service?wsdl')

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

# Set the body and call the operation
operation.body = { Operation1: { Parameter1: 'value', Parameter2: 42 } }
response = operation.call

# Access the response
response.body   # => parsed Hash
response.raw    # => raw XML string
```

## Documentation

See the [docs](docs/) folder for more detailed documentation.

## License

Released under the [MIT License](MIT-LICENSE).