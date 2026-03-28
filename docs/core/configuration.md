# Configuration

## Parse Options

`WSDL.parse(source, **options)` accepts parse-time options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `source` | `String` | (required) | HTTP(S) URL or local file path to the WSDL document |
| `http:` | client instance | `WSDL.http_client.new` | Custom HTTP client for fetching WSDL/schemas |
| `strictness:` | `Hash`, `Boolean` | all strict | Validation strictness (see [Strictness](#strictness)) |
| `sandbox_paths:`| `Array<String>`, `nil` | auto | Allowed directories for local imports (see [Sandbox Paths](#sandbox-paths)) |
| `limits:` | `Hash`, `nil` | sensible defaults | Resource limits for DoS protection (see [Limits](#limits)) |
| `config:` | `Config`, `nil` | `nil` | Reusable Config object (see [Config](#config)) |

## Client Options

`WSDL::Client.new(definition, **options)` accepts runtime options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `definition` | `Definition` | (required) | A parsed WSDL Definition (from `WSDL.parse` or `WSDL.load`) |
| `http:` | client instance | `WSDL.http_client.new` | Custom HTTP client for SOAP operation calls |
| `config:` | `Config`, `nil` | `nil` | Reusable Config object (see [Config](#config)) |
| `strictness:` | `Hash`, `Boolean` | all strict | Validation strictness (see [Strictness](#strictness)) |
| `limits:` | `Hash`, `nil` | sensible defaults | Resource limits for DoS protection (see [Limits](#limits)) |

```ruby
definition = WSDL.parse(
  '/app/wsdl/service.wsdl',
  strictness: { schema_imports: false }
)
client = WSDL::Client.new(definition)
```

## Config

`WSDL::Config` groups all behavioral settings into a frozen value object. You can pass options directly to `WSDL.parse` or `Client.new` (they are forwarded to Config) or create a reusable Config:

```ruby
# Direct keyword arguments (most common)
definition = WSDL.parse(url, strictness: false)
client = WSDL::Client.new(definition)

# Reusable Config object
config = WSDL::Config.new(strictness: false)
definition1 = WSDL.parse(url1, config:)
definition2 = WSDL.parse(url2, config:)

# Derive a modified copy
relaxed = config.with(strictness: { schema_imports: false })
```

Config is frozen after construction, like `Limits`.

## Global Defaults

Two module-level settings apply to all new clients:

```ruby
WSDL.http_client = MyHTTPClient   # default: WSDL::HTTP::Client
WSDL.logger = Rails.logger        # default: silent (NullLogger)
```

Pass `nil` to any setter to restore its default value. Limits and strictness
are not global — pass them as kwargs on `WSDL.parse` or `Client.new`.

> **Thread safety:** These are global settings shared across all clients.
> Set them once at boot time (e.g. in a Rails initializer), before creating
> any clients or spawning threads. Changing them after clients exist may
> cause inconsistent behavior. See [Thread Safety](thread-safety.md) for
> the full concurrency guide.

## Strictness

Controls how strictly the library enforces WSDL/XSD correctness. Each setting independently controls a validation concern:

| Setting | Default | Controls |
|---------|---------|----------|
| `schema_imports` | `true` | Raise on failed schema imports vs log-and-skip |
| `schema_references` | `true` | Raise on unresolved type/element references |
| `operation_overloading` | `true` | Reject WS-I R2304 operation overloading |
| `request_validation` | `true` | Validate request payloads against schema |

```ruby
# All strict (default)
strictness: true

# All relaxed
strictness: false

# Disable only one concern
strictness: { schema_imports: false }

# Disable multiple concerns
strictness: { schema_imports: false, schema_references: false }
```

When an error is raised due to a strictness check, the error message tells you exactly which setting to disable.

## Caching

The built-in parser cache has been removed. `Definition` is serializable via `WSDL.dump`/`to_h`/`to_json` and restorable via `WSDL.load` — cache at the Definition level instead:

```ruby
# Parse once
definition = WSDL.parse('http://example.com/service?wsdl')
File.write('cache.json', definition.to_json)

# Restore from cache
cached = JSON.parse(File.read('cache.json'))
definition = WSDL.load(cached)
client = WSDL::Client.new(definition)
```

Use any caching backend (file, Redis, Memcached, etc.) that can store the serialized hash.

## Limits

Limits protect against resource exhaustion from malicious or oversized WSDL documents and requests. All limits are frozen after construction. Use `Limits#with` to create a modified copy.

### All limits and defaults

| Limit | Default | Protects against |
|-------|---------|-----------------|
| `max_document_size` | 10 MB | Oversized WSDL/schema documents |
| `max_total_download_size` | 50 MB | Cumulative download exhaustion |
| `max_schemas` | 50 | Excessive schema imports |
| `max_schema_import_iterations` | 100 | Circular or excessive import chains |
| `max_elements_per_type` | 500 | Oversized complex type definitions |
| `max_attributes_per_element` | 100 | Oversized attribute lists |
| `max_type_nesting_depth` | 50 | Deep type inheritance chains |
| `max_request_elements` | 10,000 | Oversized request payloads |
| `max_request_depth` | 100 | Deeply nested request structures |
| `max_request_attributes` | 1,000 | Oversized request attribute lists |

Set any limit to `nil` to disable it.

### On WSDL.parse

```ruby
definition = WSDL.parse(url, limits: { max_schemas: 200 })
definition = WSDL.parse(url, limits: { max_document_size: 20 * 1024 * 1024 })
```

### As a Limits object

```ruby
custom = WSDL::Limits.new(max_schemas: 200, max_document_size: 20 * 1024 * 1024)
definition = WSDL.parse(url, limits: custom)
```

### When to increase limits

- **`max_schemas`** — large enterprise WSDLs with many imported XSD files.
- **`max_document_size`** — WSDLs that embed large inline schemas.
- **`max_request_elements`** — operations with very large payloads (bulk imports, batch operations).

## Logging

All log output is silently discarded by default. Assign any `Logger`-compatible object to enable logging:

```ruby
WSDL.logger = Rails.logger

# Or use Ruby's stdlib Logger
require 'logger'
WSDL.logger = Logger.new($stdout, level: :warn)
```

Reset to silent:

```ruby
WSDL.logger = nil
```

Log output includes schema import warnings (in relaxed mode), WSDL fetch activity, and security verification details.

## Sandbox Paths

Sandbox paths restrict which directories the parser may access when resolving local schema imports.

When `sandbox_paths:` is omitted (default):

- **URL WSDL**: local file access is disabled entirely. All imports must use HTTP(S) URLs.
- **File path WSDL**: sandboxed to the WSDL's parent directory.

Provide explicit paths when imports span sibling directories:

```ruby
definition = WSDL.parse(
  '/app/wsdl/system/service.wsdl',
  sandbox_paths: ['/app/wsdl/system', '/app/wsdl/common']
)
client = WSDL::Client.new(definition)
```

## XML Formatting

Request XML is compact by default (no extra whitespace). For debugging or logging, pass `pretty: true` to `to_xml`:

```ruby
puts operation.to_xml(pretty: true)
```

## HTTP Client

The HTTP client handles WSDL/schema fetching (`get`) and SOAP operation calls (`post`). The built-in `WSDL::HTTP::Client` uses Ruby's stdlib `net/http` with secure defaults.


```ruby
definition = WSDL.parse('http://example.com/service?wsdl')
client = WSDL::Client.new(definition)

client.http.open_timeout = 10
client.http.read_timeout = 60
client.http.ca_file = '/path/to/ca-bundle.crt'
```

See [HTTP Client](http-client.md) for the full security model, blocked IP ranges, custom client interface, and configuration options.

## See also

- [Getting Started](../getting_started.md)
- [HTTP Client](http-client.md)
- [Error Hierarchy](../reference/errors.md)
- [Resolving Imports](resolving-imports.md)
- [Strictness Fixture Matrix](../reference/strictness-fixture-matrix.md)
- [Thread Safety](thread-safety.md)
- [Specifications and References](../reference/specifications.md)
