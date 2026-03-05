# Getting Started

This is the docs entrypoint.

## Documentation Map

### Core

- [Building Requests](core/building-requests.md)
- [Inspecting Services](core/inspecting-services.md)
- [Handling Responses](core/handling-responses.md)
- [Configuration](core/configuration.md)
- [Resolving Imports](core/resolving-imports.md)

### Security

- [WS-Security Overview](security/ws-security.md)
- [UsernameToken](security/ws-security-username-token.md)
- [Signatures](security/ws-security-signatures.md)
- [XML Safety](security/ws-security-xml-safety.md)
- [Troubleshooting](security/ws-security-troubleshooting.md)

### Reference

- [Error Hierarchy](reference/errors.md)
- [Strict Schema Fixture Matrix](reference/strict-schema-fixture-matrix.md)
- [Specifications and References](reference/specifications.md)

## Recommended Path

1. Read this page end to end.
2. Continue with [Building Requests](core/building-requests.md).
3. Then read [Handling Responses](core/handling-responses.md).
4. Add [WS-Security Overview](security/ws-security.md) when integrating with secure SOAP endpoints.

## Quickstart

## 1. Build a Client

```ruby
require 'wsdl'

client = WSDL::Client.new('http://example.com/service?wsdl')
```

[`strict_schema`](core/configuration.md#strict-schema-mode) is enabled by default. Set `strict_schema: false` when you need best-effort parsing for incomplete enterprise WSDLs.

## 2. Discover Services and Operations

```ruby
client.services
# => { "OrderService" => { ports: { "OrderPort" => { ... } } } }

# For single service/port WSDLs (most common):
client.operations
# => ["GetOrder", "CreateOrder", "CancelOrder"]

# For multi-service WSDLs, specify service and port:
client.operations('OrderService', 'OrderPort')
# => ["GetOrder", "CreateOrder", "CancelOrder"]
```

## 3. Pick an Operation and Inspect the Contract

```ruby
# For single service/port WSDLs:
operation = client.operation('GetOrder')

# For multi-service WSDLs, specify service and port:
# operation = client.operation('OrderService', 'OrderPort', 'GetOrder')
contract = operation.contract

contract.style            # => "document/literal" or "rpc/literal"
contract.request.empty?   # => false
contract.request.body.paths
contract.request.body.tree
```

Generate a request scaffold:

```ruby
puts contract.request.body.template(mode: :minimal).to_dsl
puts contract.request.body.template(mode: :full).to_h
```

## 4. Define the Request

```ruby
operation.prepare do
  tag('GetOrder') do
    tag('orderId', 123)
  end
end
```

Validation runs as soon as the block finishes.

## 5. Add Security (Optional)

Security is configured inside the prepare block via `ws_security`.

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    timestamp expires_in: 300
    username_token 'api-user', 'secret', digest: true
    verify_response mode: :required
  end
end
```

## 6. Invoke and Read the Response

```ruby
response = operation.invoke

if response.fault?
  fault = response.fault
  puts "#{fault.code}: #{fault.reason}"
else
  response.body    # parsed SOAP body hash
  response.header  # parsed SOAP header hash
end
```

## Next

- Build robust request payloads: [Building Requests](core/building-requests.md)
- Understand response parsing and verification: [Handling Responses](core/handling-responses.md)
- Add signatures and trust policy: [WS-Security Signatures](security/ws-security-signatures.md)
