# Inspecting Services

Use `WSDL::Client` for service/port discovery and `operation.contract` for request/response introspection.

## Services and Ports

```ruby
client = WSDL::Client.new('http://example.com/service?wsdl')

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
```

## Operations

```ruby
client.operations('OrderService', 'OrderPort')
# => ["GetOrder", "CreateOrder", "CancelOrder"]
```

## Operation Contract

```ruby
operation = client.operation('OrderService', 'OrderPort', 'CreateOrder')
contract = operation.contract

contract.style          # => "document/literal" or "rpc/literal"
contract.request.empty? # => true/false
```

### Request and Response Sections

```ruby
contract.request.header
contract.request.body
contract.response.header
contract.response.body
```

Each section is a `PartContract`.

### Flat Paths

```ruby
contract.request.body.paths
# => [
#      {
#        path: ["CreateOrder", "customerId"],
#        namespace: "http://example.com/orders",
#        singular: true,
#        min_occurs: "1",
#        max_occurs: "1",
#        type: "xsd:string"
#      }
#    ]
```

### Tree Shape

```ruby
contract.request.body.tree
# => [{ name: "CreateOrder", children: [...], attributes: [...], wildcard: false, ... }]
```

### Request Templates

```ruby
minimal = contract.request.body.template(mode: :minimal)
full = contract.request.body.template(mode: :full)

puts minimal.to_dsl
puts full.to_dsl
pp minimal.to_h
```

`to_dsl` is the recommended starting point for implementation.

## Empty Input Operations

If both request header and body are empty (`contract.request.empty? == true`), the operation can be called without defining `operation.request`.
