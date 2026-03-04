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

## Validation Timing and Strictness

Validation runs immediately when the `prepare` block finishes.

`strict_schema: true` (default):

- Enforces operation-relevant schema completeness.
- Rejects unknown elements/attributes unless wildcard-permitted.
- Enforces required elements, order, and cardinality where known.

`strict_schema: false`:

- Tolerates recoverable import failures.
- Validates known structure where available.
- Allows unknown structure when schema metadata is missing.

## Resource Limits

Request AST construction enforces limits:

- `max_request_elements`
- `max_request_depth`
- `max_request_attributes`

Configure on client:

```ruby
client = WSDL::Client.new(
  wsdl,
  max_request_elements: 50_000,
  max_request_depth: 200,
  max_request_attributes: 5_000
)
```

## RPC/Literal Behavior

For `rpc/literal`, request serialization applies an operation wrapper when needed, using `soap:body@namespace` if present.

## See also

- [Getting Started](../getting_started.md)
- [Inspecting Services](inspecting-services.md)
- [Handling Responses](handling-responses.md)
- [WS-Security Overview](../security/ws-security.md)
