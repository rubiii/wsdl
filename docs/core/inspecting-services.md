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
#            location: "https://api.example.com/orders",
#            operations: [
#              { name: "GetOrder" },
#              { name: "CreateOrder" },
#              { name: "CancelOrder" },
#
#              # Overloaded operations (same name, different messages)
#              # include input_name for disambiguation:
#              { name: "Lookup", input_name: "LookupById" },
#              { name: "Lookup", input_name: "LookupByName" }
#            ]
#          }
#        }
#      }
#    }
```

## Operations

For WSDLs with a single service and port (the most common case), arguments can be omitted:

```ruby
client.operations
# => ["GetOrder", "CreateOrder", "CancelOrder"]
```

For WSDLs with multiple services or ports, specify them explicitly:

```ruby
client.operations('OrderService', 'OrderPort')
# => ["GetOrder", "CreateOrder", "CancelOrder"]
```

## Operation Contract

```ruby
# Single service/port shorthand:
operation = client.operation('CreateOrder')

# Multi-service explicit form:
# operation = client.operation('OrderService', 'OrderPort', 'CreateOrder')

# Overloaded operations (same name, different messages) need input_name: to disambiguate:
# operation = client.operation('OrderService', 'OrderPort', 'CreateOrder', input_name: 'CreateOrderBatch')
contract = operation.contract

contract.style          # => "document/literal" or "rpc/literal"
contract.request.empty? # => true/false — no header or body elements
```

When `empty?` returns `true`, the operation takes no input and can be invoked without `operation.prepare`.

### Request and Response Sections

```ruby
contract.request.header
contract.request.body
contract.response.header
contract.response.body
```

Each section is a `PartContract` with three views: `paths`, `tree`, and `template`.

### Flat Paths

`paths` returns a flat array of hashes — one per element in the tree. Useful for quick inspection and searching by path.

```ruby
contract.request.body.paths
# => [
#      {
#        path: ["CreateOrder"],
#        kind: :complex,
#        namespace: "http://example.com/orders",
#        form: "qualified",
#        singular: true,
#        min_occurs: "1",
#        max_occurs: "1",
#        attributes: [
#          { name: "priority", type: "xsd:int", required: false, list: false }
#        ],
#        wildcard: false
#      },
#      {
#        path: ["CreateOrder", "customerId"],
#        kind: :simple,
#        namespace: "http://example.com/orders",
#        form: "qualified",
#        singular: true,
#        min_occurs: "1",
#        max_occurs: "1",
#        type: "xsd:string",
#        list: false
#      }
#    ]
```

### Tree Shape

`tree` returns the same information as `paths` but in a nested structure. Each node has `children` and `attributes` arrays.

```ruby
contract.request.body.tree
# => [
#      {
#        name: "CreateOrder",
#        kind: :complex,
#        namespace: "http://example.com/orders",
#        form: "qualified",
#        min_occurs: "1",
#        max_occurs: "1",
#        required: true,
#        nillable: false,
#        singular: true,
#        attributes: [
#          { name: "priority", type: "xsd:int", required: false, list: false }
#        ],
#        children: [
#          {
#            name: "customerId",
#            kind: :simple,
#            type: "xsd:string",
#            list: false,
#            ...
#          }
#        ],
#        wildcard: false
#      }
#    ]
```

### Element Kinds

Every element in `paths` and `tree` includes a `kind` field:

| Kind | Description | Type-specific fields |
|------|-------------|---------------------|
| `:simple` | Text content with a base type | `type`, `list` |
| `:complex` | Contains child elements | `wildcard`, `children` (tree only) |
| `:recursive` | Self-referencing type (traversal stopped) | `recursive_type` |

### Attribute Metadata

Attributes on complex elements are represented as arrays of hashes with `name`, `type`, `required`, and `list`. This format is identical in both `paths` and `tree`.

```ruby
# xs:list-derived attributes parse as whitespace-separated arrays:
# <Record tags="ruby xml soap"/> => { _tags: ["ruby", "xml", "soap"] }
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

## See also

- [Getting Started](../getting_started.md)
- [Building Requests](building-requests.md)
- [Handling Responses](handling-responses.md)
