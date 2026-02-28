# Inspecting Services

Once you've loaded a WSDL document, you can inspect its structure to understand what services, ports, and operations are available.

## Services and Ports

A WSDL document defines one or more **services**, each containing one or more **ports**. A port specifies a binding and a network address (endpoint).

``` ruby
client = WSDL.new('http://example.com/service?wsdl')

client.services
# => {
#   'OrderService' => {
#     ports: {
#       'OrderServiceSoap' => {
#         type: 'http://schemas.xmlsoap.org/wsdl/soap/',
#         location: 'http://example.com/orders'
#       },
#       'OrderServiceSoap12' => {
#         type: 'http://schemas.xmlsoap.org/wsdl/soap12/',
#         location: 'http://example.com/orders'
#       }
#     }
#   }
# }
```

The `type` indicates the SOAP version:
- `http://schemas.xmlsoap.org/wsdl/soap/` - SOAP 1.1
- `http://schemas.xmlsoap.org/wsdl/soap12/` - SOAP 1.2

## Operations

Each port exposes a set of operations. List them using `operations`:

``` ruby
client.operations('OrderService', 'OrderServiceSoap')
# => ['CreateOrder', 'GetOrder', 'UpdateOrder', 'CancelOrder']
```

Service and port names can be passed as strings or symbols:

``` ruby
client.operations(:OrderService, :OrderServiceSoap)
```

## Getting an Operation

To inspect or call a specific operation:

``` ruby
operation = client.operation('OrderService', 'OrderServiceSoap', 'CreateOrder')
```

## Operation Details

Once you have an operation, you can inspect its properties:

### SOAP Version

``` ruby
operation.soap_version
# => '1.1' or '1.2'
```

### SOAP Action

``` ruby
operation.soap_action
# => 'http://example.com/CreateOrder'
```

### Endpoint

``` ruby
operation.endpoint
# => 'http://example.com/orders'
```

### Operation Style

``` ruby
operation.input_style
# => 'document/literal'

operation.output_style
# => 'document/literal'
```

## Example Request Structure

To see what structure the operation expects:

### Body

``` ruby
operation.example_body
# => {
#   CreateOrder: {
#     customerId: 'int',
#     items: [{
#       productId: 'int',
#       quantity: 'int',
#       price: 'decimal'
#     }],
#     shippingAddress: {
#       street: 'string',
#       city: 'string',
#       zipCode: 'string'
#     }
#   }
# }
```

### Header

Some operations require SOAP headers:

``` ruby
operation.example_header
# => {
#   AuthHeader: {
#     username: 'string',
#     password: 'string'
#   }
# }
```

An empty hash indicates no headers are required.

## Body Parts

For more detailed type information, use `body_parts`:

``` ruby
operation.body_parts
# => [
#   [['CreateOrder'], { namespace: 'http://example.com/', form: 'qualified', singular: true }],
#   [['CreateOrder', 'customerId'], { namespace: 'http://example.com/', form: 'unqualified', singular: true, type: 'int' }],
#   ...
# ]
```

This returns an array of paths and their metadata, useful for understanding namespaces and element qualifications.

## Error Handling

If you request an unknown service, port, or operation, an `ArgumentError` is raised with helpful information:

``` ruby
client.operation('UnknownService', 'UnknownPort', 'UnknownOp')
# ArgumentError: Unknown service "UnknownService" or port "UnknownPort".
# Here is a list of known services and port:
# {"OrderService"=>{:ports=>{"OrderServiceSoap"=>...}}}
```
