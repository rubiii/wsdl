# WSDL

[![CI](https://github.com/rubiii/wsdl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/rubiii/wsdl/actions/workflows/ci.yml) [![Gem Version](https://img.shields.io/gem/v/wsdl)](https://rubygems.org/gems/wsdl)

WSDL toolkit for Ruby. Parse WSDL 1.1 documents, inspect operation contracts, and execute SOAP calls.

## Installation

```sh
gem install wsdl
```

Or in `Gemfile`:

```ruby
gem 'wsdl'
```

## Quickstart

```ruby
require 'wsdl'

# Parse a WSDL document
client = WSDL::Client.new('http://example.com/service?wsdl')

# Discover available services, ports, and operations
client.services     # => { "OrderService" => { ports: { "OrderPort" => { ... } } } }
client.operations   # => ["GetOrder", "CreateOrder", "CancelOrder"]

# Get an operation handle
operation = client.operation('GetOrder')

# For multi-service WSDLs, specify service and port explicitly:
# client.operation('OrderService', 'OrderPort', 'GetOrder')

# Inspect the expected request structure
operation.contract.request.body.paths
# => [
#      { path: ["GetOrder", "orderId"], type: "xsd:int", min_occurs: "1", ... }
#    ]

# Generate copy-pastable starter code from the contract
puts operation.contract.request.body.template(mode: :minimal).to_dsl
# operation.prepare do
#   tag('GetOrder') do
#     tag('orderId', 'int')
#   end
# end

# Fill in the values and invoke the operation
operation.prepare do
  tag('GetOrder') do
    tag('orderId', 123)
  end
end
response = operation.invoke

# Response body is automatically parsed with schema-aware type conversion
response.body
# => { "GetOrderResponse" => { "order" => { "id" => 123, "total" => 0.9999e2,
#        "shipped" => true, "items" => [{ "name" => "Widget" }] } } }

# Access HTTP metadata and raw XML when needed
response.http_status   # => 200
response.raw           # => "<?xml version=\"1.0\" ...>"
```

## Documentation

See [Getting Started](docs/getting_started.md) for the documentation entrypoint and guide map.

## Features

- **WSDL 1.1 Only** — WSDL 2.0 documents are detected and rejected with a clear error
- **WSDL/XSD Parsing** — Full support for imports, includes, and multiple schema documents
- **Service Discovery** — Inspect services, ports, and operations programmatically
- **Contract Introspection** — Explore request/response structure with flat paths or tree views
- **Request Templates** — Generate starter code from operation contracts
- **WS-Security** — UsernameToken, Timestamps, and X.509 Signatures
- **Response Verification** — Validate signatures and timestamps on incoming messages
- **Schema-Aware Parsing** — Type conversion and array handling based on XSD metadata
- **Security Hardening** — DOCTYPE rejection, resource limits, and sandboxed file access

## License

Released under the [MIT License](MIT-LICENSE).
