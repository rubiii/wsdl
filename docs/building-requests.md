# Building Requests

This guide covers how to construct SOAP requests, including handling complex types, arrays, headers, and attributes.

## Basic Request

Set the request body using a Hash that mirrors the expected structure:

``` ruby
operation = client.operation('OrderService', 'OrderServiceSoap', 'GetOrder')

operation.body = {
  GetOrder: {
    orderId: 123
  }
}

response = operation.call
```

## Using Example Body as a Template

Use `example_body` to see the expected structure, then fill in your values:

``` ruby
operation.example_body
# => { GetOrder: { orderId: 'int' } }

operation.body = {
  GetOrder: {
    orderId: 123
  }
}
```

## Complex Types

Nested complex types are represented as nested Hashes:

``` ruby
operation.example_body
# => {
#   CreateOrder: {
#     customer: {
#       name: 'string',
#       email: 'string'
#     },
#     shippingAddress: {
#       street: 'string',
#       city: 'string',
#       zipCode: 'string'
#     }
#   }
# }

operation.body = {
  CreateOrder: {
    customer: {
      name: 'John Doe',
      email: 'john@example.com'
    },
    shippingAddress: {
      street: '123 Main St',
      city: 'Springfield',
      zipCode: '12345'
    }
  }
}
```

## Arrays

### Arrays of Complex Types

When an element can occur multiple times (arrays), provide an Array of Hashes:

``` ruby
operation.example_body
# => {
#   CreateOrder: {
#     items: [{
#       productId: 'int',
#       quantity: 'int'
#     }]
#   }
# }

operation.body = {
  CreateOrder: {
    items: [
      { productId: 1, quantity: 2 },
      { productId: 2, quantity: 1 },
      { productId: 3, quantity: 5 }
    ]
  }
}
```

### Arrays of Simple Types

For arrays of simple values, provide an Array:

``` ruby
operation.example_body
# => {
#   GetOrders: {
#     orderIds: {
#       orderId: ['int']
#     }
#   }
# }

operation.body = {
  GetOrders: {
    orderIds: {
      orderId: [101, 102, 103, 104]
    }
  }
}
```

## SOAP Headers

Some operations require SOAP headers for authentication or other purposes:

``` ruby
operation.example_header
# => {
#   AuthHeader: {
#     token: 'string'
#   }
# }

operation.header = {
  AuthHeader: {
    token: 'abc123secret'
  }
}

operation.body = {
  GetOrder: { orderId: 123 }
}

response = operation.call
```

## XML Attributes

To set XML attributes on an element, prefix the attribute name with an underscore (`_`):

``` ruby
operation.body = {
  CreatePayment: {
    amount: {
      _currency: 'USD',
      amount: 99.99
    }
  }
}
```

This produces XML like:

``` xml
<amount currency="USD">99.99</amount>
```

### Attributes on Complex Types

``` ruby
operation.body = {
  UpdateOrder: {
    order: {
      _id: 123,
      _status: 'processing',
      items: [
        { productId: 1, quantity: 2 }
      ]
    }
  }
}
```

## Raw XML Envelope

If you need complete control, you can provide a raw XML envelope instead of using the body Hash:

``` ruby
operation.xml_envelope = <<~XML
  <?xml version="1.0" encoding="UTF-8"?>
  <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Header>
      <auth:Token xmlns:auth="http://example.com/auth">secret123</auth:Token>
    </soap:Header>
    <soap:Body>
      <GetOrder xmlns="http://example.com/orders">
        <orderId>123</orderId>
      </GetOrder>
    </soap:Body>
  </soap:Envelope>
XML

response = operation.call
```

When `xml_envelope` is set, the `body` and `header` properties are ignored.

## Previewing the Request

To see the XML that will be sent without making the call:

``` ruby
operation.body = {
  GetOrder: { orderId: 123 }
}

puts operation.build
```

This outputs the complete SOAP envelope XML.

## Customizing the Request

### Endpoint

Override the endpoint from the WSDL:

``` ruby
operation.endpoint = 'http://staging.example.com/orders'
```

### SOAP Action

Override the SOAPAction header:

``` ruby
operation.soap_action = 'http://example.com/custom/GetOrder'
```

### SOAP Version

Switch between SOAP 1.1 and 1.2:

``` ruby
operation.soap_version = '1.2'
```

### Encoding

Change the character encoding (default is UTF-8):

``` ruby
operation.encoding = 'ISO-8859-1'
```

### HTTP Headers

Set custom HTTP headers:

``` ruby
operation.http_headers = {
  'Content-Type' => 'text/xml;charset=UTF-8',
  'SOAPAction' => '"http://example.com/GetOrder"',
  'X-Custom-Header' => 'custom-value'
}
```

## Error Handling

The library validates your input against the expected structure:

``` ruby
# Wrong: Array provided for singular complex type
operation.body = {
  GetOrder: [{ orderId: 123 }]
}
operation.build
# => ArgumentError: Expected a Hash for the :GetOrder complex type

# Wrong: Hash provided for array of complex types
operation.body = {
  CreateOrder: {
    items: { productId: 1, quantity: 2 }  # Should be an Array
  }
}
operation.build
# => ArgumentError: Expected an Array of Hashes for the :items complex type

# Wrong: Array provided for singular simple type
operation.body = {
  GetOrder: {
    orderId: [123, 456]  # Should be a single value
  }
}
operation.build
# => ArgumentError: Unexpected Array for the :orderId simple type
```
