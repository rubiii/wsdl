# Handling Responses

`operation.invoke` returns `WSDL::Response`.

## Basic Access

```ruby
response = operation.invoke

response.raw          # raw SOAP XML string
response.body         # parsed SOAP body hash
response.header       # parsed SOAP header hash (or nil)
response.envelope_hash
```

## Schema-Aware Parsing

When output schema metadata is available, response parsing performs type conversion for known XML Schema types (for example integer, boolean, decimal, date/time) and preserves array semantics for repeating elements.

## XML Attributes

When schema metadata is available, XML attributes on response elements are
extracted with an underscore prefix and coerced to the appropriate Ruby type:

```ruby
response.body[:InitialResponse][:_transactionKey]  # => "TXN-98765"
response.body[:Item][:_active]                      # => true (xsd:boolean)
response.body[:Record][:_score]                     # => 42 (xsd:int)
```

This mirrors the convention used by `template.to_h`, which shows expected
attributes as `_`-prefixed keys.

Without schema metadata, all attributes are extracted as strings.

## XPath and XML Inspection

```ruby
doc = response.doc
namespaces = response.xml_namespaces
nodes = response.xpath('//ns:OrderId', 'ns' => 'http://example.com/orders')
```

Use this when you need exact XML-level inspection beyond hash parsing.

## SOAP Fault Detection

Check for SOAP faults before accessing the body:

```ruby
response = operation.invoke

if response.fault?
  fault = response.fault
  puts fault.code      # "soap:Server" (1.1) or "env:Receiver" (1.2)
  puts fault.reason    # "Something went wrong"
  puts fault.detail    # { Error: { Code: "500" } } or nil
  puts fault.role      # faultactor (1.1) or Role (1.2)
  puts fault.node      # Node URI (SOAP 1.2 only)
  puts fault.subcodes  # ["app:DbError"] (SOAP 1.2 only, empty for 1.1)
else
  puts response.body
end
```

## Security Verification

```ruby
security = response.security

security.signature_present?
security.valid?
security.errors
security.signed_elements
```

Strict verification with raised errors:

```ruby
begin
  response.security.verify!
rescue WSDL::SecurityError => e
  warn e.message
end
```

## Verification Policy

Verification behavior is configured in the request DSL:

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    verify_response mode: :required
  end
end
```

Modes:

- `:required` (default): signature must be present, valid, and must sign SOAP Body.
- `:if_present`: verify when signature exists.
- `:disabled`: skip verification.

## See also

- [Getting Started](../getting_started.md)
- [Error Hierarchy](../reference/errors.md)
- [WS-Security Overview](../security/ws-security.md)
- [WS-Security Troubleshooting](../security/ws-security-troubleshooting.md)
