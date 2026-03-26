# WSDL

[![CI](https://github.com/rubiii/wsdl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/rubiii/wsdl/actions/workflows/ci.yml) [![Gem Version](https://img.shields.io/gem/v/wsdl)](https://rubygems.org/gems/wsdl)

WSDL toolkit for Ruby. Turn WSDL 1.1 documents into inspectable definitions and callable operations.

## Installation

```sh
gem install wsdl
```

Or in `Gemfile`:

```ruby
gem 'wsdl'
```

## Requirements

- Ruby 3.3+
- [Nokogiri](https://nokogiri.org/) >= 1.19.1 (installed automatically)

## Quickstart

```ruby
require 'wsdl'

# Parse a WSDL and create a client
definition = WSDL.parse('http://example.com/service?wsdl')
client = WSDL::Client.new(definition)

# The definition is serializable — cache it to skip re-parsing
File.write('cache.json', definition.to_json)
definition = WSDL.load(JSON.parse(File.read('cache.json')))

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
response = operation.invoke do
  tag('GetOrder') do
    tag('orderId', 123)
  end
end

# Response body is automatically parsed with schema-aware type conversion
response.body
# => { "GetOrderResponse" => { "order" => { "id" => 123, "total" => 0.9999e2,
#        "shipped" => true, "items" => [{ "name" => "Widget" }] } } }

# Check for SOAP faults
if response.fault?
  fault = response.fault
  puts "#{fault.code}: #{fault.reason}"   # => "soap:Server: Order not found"
end

# Access HTTP metadata and raw XML when needed
response.http_status   # => 200
response.xml           # => "<?xml version=\"1.0\" ...>"
```

## Documentation

See [Getting Started](docs/getting_started.md) for the full guide map.

- [Inspecting Services](docs/core/inspecting-services.md) — discover operations and inspect contracts
- [Building Requests](docs/core/building-requests.md) — request DSL, headers, namespaces, templates
- [Handling Responses](docs/core/handling-responses.md) — parsing, faults, security verification
- [Configuration](docs/core/configuration.md) — strictness, limits, caching, HTTP client
- [WS-Security](docs/security/ws-security.md) — UsernameToken, signatures, timestamps
- [Error Reference](docs/reference/errors.md) — full error hierarchy and rescue patterns

## Features

- **WSDL/XSD Parsing** — Full support for imports, includes, and multiple schema documents
- **Service Discovery** — Inspect services, ports, and operations programmatically
- **Contract Introspection** — Explore request/response structure with flat paths or tree views
- **Request Templates** — Generate starter code from operation contracts
- **WS-Security** — UsernameToken, Timestamps, and X.509 Signatures
- **Response Verification** — Validate signatures and timestamps on incoming messages
- **Schema-Aware Parsing** — Type conversion and array handling based on XSD metadata
- **Security Hardening** — DOCTYPE rejection, resource limits, and sandboxed file access

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Security issues: [SECURITY.md](SECURITY.md).

## License

Released under the [MIT License](MIT-LICENSE).
