# WSDL

WSDL toolkit for Ruby. Parse WSDL documents, inspect operation contracts, and execute SOAP calls.

## Features

- **WSDL/XSD Parsing** — Full support for imports, includes, and multiple schema documents
- **Service Discovery** — Inspect services, ports, and operations programmatically
- **Contract Introspection** — Explore request/response structure with flat paths or tree views
- **Request Templates** — Generate starter code from operation contracts
- **WS-Security** — UsernameToken, Timestamps, and X.509 Signatures
- **Response Verification** — Validate signatures and timestamps on incoming messages
- **Schema-Aware Parsing** — Type conversion and array handling based on XSD metadata
- **Security Hardening** — DOCTYPE rejection, resource limits, and sandboxed file access

## Installation

```sh
gem install wsdl
```

Or in `Gemfile`:

```ruby
gem 'wsdl'
gem 'httpclient' # optional; default HTTP adapter
```

## Quickstart

```ruby
require 'wsdl'

# Parse a WSDL document
client = WSDL::Client.new('http://example.com/service?wsdl')

# Discover available services and ports
client.services
# => {
#      "OrderService" => {
#        ports: {
#          "OrderPort" => {
#            type: "http://schemas.xmlsoap.org/wsdl/soap/",
#            location: "https://api.example.com/orders"
#          }
#        }
#      }
#    }

# List operations for a service/port
client.operations('OrderService', 'OrderPort')
# => ["GetOrder", "CreateOrder", "CancelOrder"]

# Get an operation handle
operation = client.operation('OrderService', 'OrderPort', 'GetOrder')

# Inspect the expected request structure
operation.contract.request.body.paths
# => [
#      { path: ["GetOrder", "orderId"], type: "xsd:int", min_occurs: "1", ... }
#    ]

# Generate starter code from the contract
puts operation.contract.request.body.template(mode: :minimal).to_dsl
# tag('GetOrder') do
#   tag('orderId', '')
# end

# Build and execute the request
operation.request do
  tag('GetOrder') do
    tag('orderId', 123)
  end

  ws_security do
    timestamp expires_in: 300
    verify_response mode: :required
  end
end

response = operation.call
response.body   # => { "GetOrderResponse" => { "order" => { ... } } }
```

## Documentation

See the [docs](docs/index.md) folder for guides on configuration, WS-Security, and more.

## License

Released under the [MIT License](MIT-LICENSE).