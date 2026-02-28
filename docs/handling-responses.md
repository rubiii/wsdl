# Handling Responses

After calling an operation, you receive a `WSDL::Response` object that provides multiple ways to access the response data.

## Making a Call

``` ruby
operation = client.operation('OrderService', 'OrderServiceSoap', 'GetOrder')
operation.body = { GetOrder: { orderId: 123 } }

response = operation.call
```

## Accessing Response Data

### Parsed Body

The most common way to access response data is through the `body` method, which returns the SOAP body as a parsed Hash:

``` ruby
response.body
# => {
#   get_order_response: {
#     order: {
#       id: '123',
#       status: 'shipped',
#       customer_name: 'John Doe'
#     }
#   }
# }
```

Note: Element names are converted to snake_case symbols.

### Parsed Header

Access SOAP headers in the response:

``` ruby
response.header
# => {
#   session_info: {
#     session_id: 'abc123',
#     expires_at: '2024-01-15T10:30:00Z'
#   }
# }
```

Returns an empty Hash or nil if no headers are present.

### Full Parsed Response

To get the entire parsed envelope (including both header and body):

``` ruby
response.hash
# => {
#   envelope: {
#     header: { ... },
#     body: { ... }
#   }
# }
```

## Raw XML Access

### Raw Response String

Get the unprocessed XML response:

``` ruby
response.raw
# => '<?xml version="1.0"?><soap:Envelope xmlns:soap="...">...</soap:Envelope>'
```

Useful for debugging or when you need to process the XML yourself.

### Nokogiri Document

Access the response as a Nokogiri XML document for advanced querying:

``` ruby
response.doc
# => #<Nokogiri::XML::Document:...>

response.doc.at_xpath('//order/status').text
# => 'shipped'
```

## XPath Queries

Query the response document directly using XPath:

``` ruby
response.xpath('//order')
# => [#<Nokogiri::XML::Element:... name="order">]

response.xpath('//order/status').first.text
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

# Query using the document's namespace prefixes
response.xpath('//ns1:order')
```

You can also provide custom namespace mappings:

``` ruby
custom_ns = {
  'o' => 'http://example.com/orders',
  's' => 'http://schemas.xmlsoap.org/soap/envelope/'
}

response.xpath('//o:order', custom_ns)
```

## Working with the Parsed Data

### Navigating Nested Structures

``` ruby
body = response.body

# Access nested data
order = body[:get_order_response][:order]
order[:id]           # => '123'
order[:status]       # => 'shipped'
order[:customer_name] # => 'John Doe'
```

### Handling Arrays

When the response contains multiple elements:

``` ruby
response.body
# => {
#   get_orders_response: {
#     orders: {
#       order: [
#         { id: '1', status: 'shipped' },
#         { id: '2', status: 'pending' },
#         { id: '3', status: 'delivered' }
#       ]
#     }
#   }
# }

orders = response.body[:get_orders_response][:orders][:order]
orders.each do |order|
  puts "Order #{order[:id]}: #{order[:status]}"
end
```

### Handling Missing Data

Always check for the presence of nested keys:

``` ruby
body = response.body

if body[:get_order_response] && body[:get_order_response][:order]
  order = body[:get_order_response][:order]
  # process order
end

# Or use dig (Ruby 2.3+)
order = body.dig(:get_order_response, :order)
if order
  # process order
end
```

## SOAP Faults

SOAP faults are returned in the body like any other response:

``` ruby
response.body
# => {
#   fault: {
#     faultcode: 'soap:Client',
#     faultstring: 'Invalid order ID',
#     detail: {
#       error_code: '1001',
#       message: 'Order with ID 999 not found'
#     }
#   }
# }

if response.body[:fault]
  fault = response.body[:fault]
  raise "SOAP Fault: #{fault[:faultstring]}"
end
```

## Debugging Responses

When troubleshooting, examine the raw response:

``` ruby
response = operation.call

# Print raw XML
puts response.raw

# Pretty print the parsed hash
require 'pp'
pp response.body

# Inspect the XML structure
puts response.doc.to_xml(indent: 2)
```
