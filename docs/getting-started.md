# Getting Started

## 1. Build a Client

```ruby
require 'wsdl'

client = WSDL::Client.new('http://example.com/service?wsdl')
```

`strict_schema` is enabled by default. Set `strict_schema: false` when you need best-effort parsing for incomplete enterprise WSDLs.

## 2. Discover Services and Operations

```ruby
client.services
# => { "ServiceName" => { ports: { "PortName" => { ... } } } }

client.operations('ServiceName', 'PortName')
# => ["GetOrder", "CreateOrder"]
```

## 3. Pick an Operation and Inspect the Contract

```ruby
operation = client.operation('ServiceName', 'PortName', 'GetOrder')
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

response.raw     # raw SOAP XML
response.body    # parsed SOAP body hash
response.header  # parsed SOAP header hash
```
