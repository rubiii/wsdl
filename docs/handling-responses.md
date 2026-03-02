# Handling Responses

After calling an operation, you receive a `WSDL::Response` object that provides multiple ways to access the response data.

``` ruby
operation = wsdl.operation('OrderService', 'OrderServiceSoap', 'GetOrder')
operation.body = { GetOrder: { OrderId: 123 } }

response = operation.call
```

## Raw XML Access

The simplest way to inspect a response is to look at the raw XML.

### Raw Response String

``` ruby
response.raw
# => '<?xml version="1.0"?><soap:Envelope xmlns:soap="...">...</soap:Envelope>'
```

### Nokogiri Document

For more control, access the response as a Nokogiri XML document:

``` ruby
response.doc
# => #<Nokogiri::XML::Document:...>

response.doc.at_xpath('//Order/Status').text
# => 'shipped'
```

## XPath Queries

Query the response document directly using XPath:

``` ruby
response.xpath('//Order')
# => [#<Nokogiri::XML::Element:... name="Order">]

response.xpath('//Order/Status').first.text
# => 'shipped'
```

### Working with Namespaces

The `xpath` method uses the document's namespaces by default:

``` ruby
response.xml_namespaces
# => {
#   'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
#   'xmlns:ns1' => 'http://example.com/orders'
# }

response.xpath('//ns1:Order')
```

You can also provide custom namespace mappings:

``` ruby
response.xpath('//o:Order', 'o' => 'http://example.com/orders')
```

## Parsed Header

Access SOAP headers as a Hash with symbol keys:

``` ruby
response.header
# => {
#   SessionInfo: {
#     SessionId: 'abc123',
#     ExpiresAt: '2024-01-15T10:30:00Z'
#   }
# }
```

Returns an empty Hash if no headers are present.

## Parsed Envelope (Raw)

Use `envelope_hash` when you need the full SOAP envelope (header + body) without schema-aware type conversion:

``` ruby
response.envelope_hash
# => {
#   Envelope: {
#     Header: { SessionId: 'abc123' },
#     Body:   { GetOrderResponse: { ... } }
#   }
# }
```

`to_envelope_hash` is an alias:

``` ruby
response.to_envelope_hash == response.envelope_hash
# => true
```

## Parsed Body

The `body` method returns the SOAP body as a Hash. Because the response is parsed using schema information from the WSDL, you get two key benefits:

1. **Type Conversions** - XSD types are converted to Ruby types
2. **Consistent Arrays** - Elements with `maxOccurs > 1` are always arrays

``` ruby
response.body
# => {
#   GetOrderResponse: {
#     Order: {
#       Id: 123,                            # Integer
#       Total: BigDecimal("149.97"),        # BigDecimal
#       Shipped: true,                      # Boolean
#       OrderDate: Date.new(2024, 1, 15),   # Date
#       Items: [                            # Always an array
#         { Name: 'Widget', Quantity: 3 }
#       ]
#     }
#   }
# }
```

Element names are converted to symbols, preserving their original casing from the WSDL.

### Type Conversions

The following XSD types are automatically converted:

| XSD Type | Ruby Type |
|----------|-----------|
| `xsd:string`, `xsd:token`, `xsd:anyURI` | `String` |
| `xsd:int`, `xsd:integer`, `xsd:long`, `xsd:short`, `xsd:byte` | `Integer` |
| `xsd:decimal` | `BigDecimal` |
| `xsd:float`, `xsd:double` | `Float` |
| `xsd:boolean` | `true` / `false` |
| `xsd:date` | `Date` |
| `xsd:dateTime`, `xsd:time` | `Time` |
| `xsd:base64Binary`, `xsd:hexBinary` | `String` (decoded) |

Unknown types are returned as strings.

### Consistent Array Handling

When the schema defines an element with `maxOccurs="unbounded"` or `maxOccurs > 1`, that element is always returned as an array—even when only one element is present:

``` ruby
# Schema: <element name="Item" maxOccurs="unbounded"/>

# One item in response - still an array
response.body[:Order][:Items]
# => [{ Name: "Widget", Price: BigDecimal("49.99") }]

# Multiple items - also an array
response.body[:Order][:Items]
# => [
#      { Name: "Widget", Price: BigDecimal("49.99") },
#      { Name: "Gadget", Price: BigDecimal("29.99") }
#    ]
```

### Nil Values

Elements with `xsi:nil="true"` are returned as `nil`:

``` ruby
response.body[:Value]  # => nil
```

### Unknown Elements

Elements not defined in the schema are included as strings:

``` ruby
response.body[:KnownElement]    # => 42 (Integer per schema)
response.body[:UnknownElement]  # => "42" (String, not in schema)
```

## Working with Parsed Data

### Navigating Nested Structures

``` ruby
order = response.body[:GetOrderResponse][:Order]

order[:Id]     # => 123
order[:Status] # => 'shipped'
```

### Safe Access with dig

``` ruby
order = response.body.dig(:GetOrderResponse, :Order)
if order
  puts "Order ID: #{order[:Id]}"
end
```

### Iterating Arrays

``` ruby
items = response.body.dig(:GetOrderResponse, :Order, :Items)
items.each do |item|
  puts "#{item[:Name]}: #{item[:Quantity]}"
end
```

## SOAP Faults

SOAP faults are returned in the body like any other response:

``` ruby
if response.body[:Fault]
  fault = response.body[:Fault]
  raise "SOAP Fault: #{fault[:faultstring]}"
end
```

## Debugging

``` ruby
# Print raw XML
puts response.raw

# Pretty print parsed body
require 'pp'
pp response.body

# Inspect XML structure
puts response.doc.to_xml(indent: 2)
```
