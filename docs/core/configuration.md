# Configuration

## Client Options

`WSDL::Client.new(wsdl, **options)` supports:

- `http:` custom HTTP adapter instance.
- `pretty_print:` format generated request XML (`true` default).
- `cache:` parser cache (`:default`, custom cache instance, or `nil`).
- `sandbox_paths:` allowed local import directories.
- `limits:` custom `WSDL::Limits` instance.
- `reject_doctype:` reject DOCTYPE declarations (`true` default).
- `strict_schema:` strict schema parsing + strict request validation (`true` default).
- `max_request_elements:` override request AST element limit.
- `max_request_depth:` override request AST depth limit.
- `max_request_attributes:` override request AST attribute limit.

Example:

```ruby
client = WSDL::Client.new(
  '/app/wsdl/service.wsdl',
  strict_schema: false,
  pretty_print: false,
  reject_doctype: true,
  max_request_elements: 20_000
)
```

## Strict Schema Mode

`strict_schema: true`:

- Recoverable schema import failures raise `WSDL::SchemaImportError`.
- Request validation is strict for known operation metadata.

`strict_schema: false`:

- Recoverable import failures are tolerated (best effort).
- Request validation is relaxed for unknown structure.

## Cache

### Per Client

```ruby
client = WSDL::Client.new(wsdl, cache: nil) # disable
```

### Global Default

```ruby
WSDL.cache = WSDL::Cache.new
WSDL.cache = nil
```

Parser cache keys include source identity, sandbox paths, limits, DOCTYPE policy, strict schema mode, and adapter cache identity.

## Limits

Global default:

```ruby
WSDL.limits = WSDL::Limits.new
```

Override one value:

```ruby
WSDL.limits = WSDL.limits.with(max_schemas: 200)
```

Useful request-side limits:

- `max_request_elements` (default `10_000`)
- `max_request_depth` (default `100`)
- `max_request_attributes` (default `1_000`)

## Sandbox Paths

When `sandbox_paths` is omitted:

- URL WSDL or inline XML: local file access disabled.
- File path WSDL: sandbox defaults to WSDL parent directory.

Provide explicit paths for sibling import trees:

```ruby
client = WSDL::Client.new(
  '/app/wsdl/system/service.wsdl',
  sandbox_paths: ['/app/wsdl/system', '/app/wsdl/common']
)
```

## HTTP Adapter Contract

Client adapters must implement:

1. `#post(endpoint, headers, body)`
2. `#cache_key` (stable non-empty identity)
3. `#client` (returns underlying client object used by `client.http`)

Set global adapter class:

```ruby
WSDL.http_adapter = MyAdapterClass
```

Or pass instance per client:

```ruby
client = WSDL::Client.new(wsdl, http: MyAdapterClass.new)
```

## Pretty Printing

Set `pretty_print: false` for servers sensitive to XML whitespace.

```ruby
client = WSDL::Client.new(wsdl, pretty_print: false)
```

## DOCTYPE Rejection

DOCTYPE is blocked by default as defense-in-depth:

```ruby
client = WSDL::Client.new(wsdl, reject_doctype: true)
```

Disable only for trusted payloads.

## See also

- [Getting Started](../getting_started.md)
- [Resolving Imports](resolving-imports.md)
- [Strict Schema Fixture Matrix](../reference/strict-schema-fixture-matrix.md)
- [Specifications and References](../reference/specifications.md)
