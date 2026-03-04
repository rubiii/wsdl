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

`response.to_hash` is an alias of `response.body`.

## Schema-Aware Parsing

When output schema metadata is available, response parsing performs type conversion for known XML Schema types (for example integer, boolean, decimal, date/time) and preserves array semantics for repeating elements.

## XPath and XML Inspection

```ruby
doc = response.doc
namespaces = response.xml_namespaces
nodes = response.xpath('//ns:OrderId', 'ns' => 'http://example.com/orders')
```

Use this when you need exact XML-level inspection beyond hash parsing.

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
rescue WSDL::SignatureVerificationError, WSDL::TimestampValidationError => e
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

- `:required` (default): signature must be present and valid.
- `:if_present`: verify when signature exists.
- `:disabled`: skip verification.

## See also

- [Getting Started](../getting_started.md)
- [WS-Security Overview](../security/ws-security.md)
- [WS-Security Troubleshooting](../security/ws-security-troubleshooting.md)
