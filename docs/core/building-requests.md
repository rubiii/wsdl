# Building Requests

`operation.prepare { ... }` is the single structured request interface.

## Core DSL

```ruby
operation.prepare do
  tag('CreateOrder') do
    tag('customerId', 'C-123')
    tag('amount', '42.50')
  end
end
```

Reserved DSL methods:

- `tag`
- `header`
- `body`
- `ws_security`
- `text`
- `cdata`
- `comment`
- `pi`
- `xmlns`
- `attribute`

If an element name matches a reserved method name, use `tag('name')`.

## HTTP Headers

Auto-generated HTTP headers (Content-Type, SOAPAction) are derived from the operation's SOAP version, action, and encoding. Use `http_headers=` to merge custom headers on top — user values win on conflict, while auto-generated defaults are preserved:

```ruby
# Add a custom header alongside auto-generated ones
operation.http_headers = { 'X-Auth-Token' => 'bearer-abc123' }
operation.http_headers
# => { "Content-Type" => "text/xml;charset=UTF-8",
#      "SOAPAction"   => "\"urn:example#GetOrder\"",
#      "X-Auth-Token" => "bearer-abc123" }

# Override an auto-generated header
operation.http_headers = { 'Content-Type' => 'application/xml' }
```

Custom headers are cleared by `operation.reset!`.

## Header vs Body

Top-level content defaults to SOAP body.

```ruby
operation.prepare do
  header do
    tag('AuthToken', 'secret')
  end

  tag('GetOrder') do
    tag('orderId', 123)
  end
end
```

`body do ... end` is optional and equivalent for top-level body content.

## Attributes and Namespaces

```ruby
operation.prepare do
  xmlns('ord', 'http://example.com/orders')

  tag('ord:CreateOrder') do
    attribute('priority', 'high')
    tag('customerId', 'C-123')
  end
end
```

Rules:

- Element and attribute names are validated as XML NCName/QName.
- Prefixed names require a declared namespace.
- Reserved prefixes cannot be overridden: `wsse`, `wsu`, `ds`, `ec`, `env`, `soap`, `soap12`, `xsi`.

## Text, CDATA, Comments, PI

```ruby
operation.prepare do
  tag('Submit') do
    text('normal text <escaped>')
    cdata('<raw xml="kept as-is"/>')
    comment('diagnostic marker')
    pi('xml-stylesheet', 'type="text/xsl" href="style.xsl"')
  end
end
```

- Text and attribute values are XML-escaped automatically.
- CDATA preserves verbatim content.

## Contract-Guided Scaffolding

Use `operation.contract` to generate a starting request:

```ruby
template = operation.contract.request.body.template(mode: :minimal)
puts template.to_dsl
```

Modes:

- `:minimal`: required elements/attributes only.
- `:full`: includes optional content and wildcard hints.

## Checking Preparation State

Use `operation.prepared?` to check whether `prepare` has been called:

```ruby
operation.prepared?  # => false

operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }
end

operation.prepared?  # => true

operation.reset!
operation.prepared?  # => false
```

## Validation Timing and Strictness

Validation runs immediately when the `prepare` block finishes. See [Strict Schema Mode](configuration.md#strict-schema-mode) for full details.

`strict_schema: true` (default):

- Enforces operation-relevant schema completeness.
- Rejects unknown elements/attributes unless wildcard-permitted.
- Enforces required elements, order, and cardinality where known.

`strict_schema: false`:

- Tolerates recoverable import failures.
- Validates known structure where available.
- Allows unknown structure when schema metadata is missing.

## Resource Limits

Request AST construction enforces [resource limits](configuration.md#limits):

- `max_request_elements`
- `max_request_depth`
- `max_request_attributes`

Configure via `limits:`:

```ruby
client = WSDL::Client.new(
  wsdl,
  limits: WSDL.limits.with(
    max_request_elements: 50_000,
    max_request_depth: 200,
    max_request_attributes: 5_000
  )
)
```

## RPC/Literal Behavior

For `rpc/literal`, request serialization applies an operation wrapper when needed, using `soap:body@namespace` if present.

## See also

- [Getting Started](../getting_started.md)
- [Configuration](configuration.md)
- [Inspecting Services](inspecting-services.md)
- [Handling Responses](handling-responses.md)
- [WS-Security Overview](../security/ws-security.md)
