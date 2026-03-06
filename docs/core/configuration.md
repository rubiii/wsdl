# Configuration

## Client Options

`WSDL::Client.new(wsdl, **options)` accepts infrastructure options directly and forwards behavioral options to `WSDL::Config`:

### Infrastructure options (on Client)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `wsdl` | `String` | (required) | HTTP(S) URL or local file path to the WSDL document |
| `http:` | adapter instance | `WSDL.http_adapter.new` | Custom HTTP adapter (see [HTTP Adapter](#http-adapter)) |
| `cache:` | `Cache`, `nil`, `false` | `nil` | Parser cache — `nil` uses global, `false` disables (see [Cache](#cache)) |
| `config:` | `Config`, `nil` | `nil` | Reusable Config object (see [Config](#config)) |

### Behavioral options (via Config)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format_xml:` | `Boolean` | `true` | Format generated request XML with indentation |
| `strict_schema:` | `Boolean` | `true` | Strict schema imports and request validation (see [Strict Schema Mode](#strict-schema-mode)) |
| `sandbox_paths:`| `Array<String>`, `nil` | auto | Allowed directories for local imports (see [Sandbox Paths](#sandbox-paths)) |
| `limits:` | `Limits`, `nil` | `WSDL.limits` | Resource limits for DoS protection (see [Limits](#limits)) |

```ruby
client = WSDL::Client.new(
  '/app/wsdl/service.wsdl',
  strict_schema: false,
  format_xml: false
)
```

## Config

`WSDL::Config` groups all behavioral settings into a frozen value object. You can pass options directly to the Client (they are forwarded to Config) or create a reusable Config:

```ruby
# Direct keyword arguments (most common)
client = WSDL::Client.new(wsdl, format_xml: false, strict_schema: false)

# Reusable Config object
config = WSDL::Config.new(format_xml: false, strict_schema: false)
client1 = WSDL::Client.new(wsdl1, config:)
client2 = WSDL::Client.new(wsdl2, config:)

# Derive a modified copy
relaxed = config.with(strict_schema: false)
```

Config is frozen after construction, like `Limits`.

## Global Defaults

Four module-level settings apply to all new clients:

```ruby
WSDL.http_adapter = MyAdapterClass             # default: WSDL::HTTPAdapter
WSDL.cache = WSDL::Cache.new(max_entries: 50)  # default: LRU cache, 50 entries
WSDL.limits = WSDL::Limits.new                 # default: sensible defaults
WSDL.logger = Rails.logger                     # default: silent (NullLogger)
```

Pass `nil` to any setter to restore its default value.

> **Thread safety:** These are global settings shared across all clients.
> Set them once at boot time (e.g. in a Rails initializer), before creating
> any clients or spawning threads. Changing them after clients exist may
> cause inconsistent behavior.

## Strict Schema Mode

Controls how the library handles incomplete or broken schema imports and how strictly requests are validated.

`strict_schema: true` (default):

- Recoverable schema import failures raise `SchemaImportError`.
- Request validation is strict for known operation metadata.

`strict_schema: false`:

- Recoverable import failures are logged and skipped (best effort).
- Request validation is relaxed for unknown structure caused by incomplete schema metadata.
- Structural WSDL reference errors (e.g. unresolved `message`/`part` in bindings) still raise.

Use `strict_schema: false` for large enterprise WSDLs with external schema dependencies that are unavailable or broken.

## Cache

The parser cache avoids re-parsing the same WSDL on repeated client construction. Cache keys include the WSDL source, sandbox paths, limits, strict schema mode, and HTTP adapter identity.

The built-in `WSDL::Cache` is a thread-safe in-memory LRU cache. When the entry limit is reached, the least recently used entry is evicted.

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_entries:` | `Integer`, `nil` | `50` | Maximum number of cached entries. LRU eviction when exceeded. `nil` for unlimited. |
| `ttl:` | `Integer`, `nil` | `nil` | Time-to-live in seconds. Expired entries are recomputed on next access. `nil` for no expiry. |

### Per-client

```ruby
client = WSDL::Client.new(wsdl)                    # use WSDL.cache (default)
client = WSDL::Client.new(wsdl, cache: false)      # disable for this client
client = WSDL::Client.new(wsdl, cache: my_cache)   # use a custom cache instance
```

### Global

```ruby
WSDL.cache = WSDL::Cache.new(max_entries: 50)       # LRU cache, max 50 entries (default)
WSDL.cache = WSDL::Cache.new(max_entries: 200)      # raise the entry limit
WSDL.cache = WSDL::Cache.new(ttl: 3600)             # 1-hour TTL
WSDL.cache = nil                                    # disable caching globally
```

Custom caches must implement `fetch(key) { ... }` and `clear`.

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

### Global default

```ruby
WSDL.limits = WSDL::Limits.new(max_schemas: 200)
```

### Override a single value

```ruby
WSDL.limits = WSDL.limits.with(max_schemas: 200)
```

### Per-client

```ruby
custom_limits = WSDL.limits.with(max_document_size: 20 * 1024 * 1024)
client = WSDL::Client.new(wsdl, limits: custom_limits)
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
client = WSDL::Client.new(
  '/app/wsdl/system/service.wsdl',
  sandbox_paths: ['/app/wsdl/system', '/app/wsdl/common']
)
```

## XML Formatting

Set `format_xml: false` for servers sensitive to XML whitespace:

```ruby
client = WSDL::Client.new(wsdl, format_xml: false)
```

### Per-operation override

Each operation inherits `format_xml` from the client config but can override it individually:

```ruby
client = WSDL::Client.new(wsdl)  # format_xml: true by default

operation = client.operation('SendData')
operation.format_xml = false  # disable formatting for this operation only
```

This is useful when most operations work fine with formatted XML but a specific operation requires compact output (e.g., a whitespace-sensitive server endpoint). The override is cleared by `operation.reset!`.

## HTTP Adapter

The HTTP adapter handles WSDL/schema fetching (`get`) and SOAP operation calls (`post`).

### Adapter interface

Custom adapters must implement:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get` | `get(url) → HTTPResponse` | Fetch WSDL and schema documents |
| `post` | `post(url, headers, body) → HTTPResponse` | Send SOAP requests |
| `cache_key` | `cache_key → String` | Stable non-empty identity for cache partitioning |
| `config` | `config → Object` | Configuration object exposed via `client.http` (e.g. timeouts, SSL) |

```ruby
class MyHTTPAdapter
  def initialize
    @connection = Faraday.new
  end

  # Expose the Faraday connection for user configuration
  # (e.g. client.http.options.timeout = 30).
  attr_reader :connection
  alias config connection

  def cache_key
    'my-http-adapter:v1'
  end

  def get(url)
    @connection.get(url).body
  end

  def post(url, headers, body)
    @connection.post(url, body, headers).body
  end
end
```

### Setting the adapter

```ruby
# Global (all new clients)
WSDL.http_adapter = MyHTTPAdapter

# Per-client
client = WSDL::Client.new(wsdl, http: MyHTTPAdapter.new)
```

### Default adapter

The built-in `WSDL::HTTPAdapter` uses Ruby's stdlib `net/http` with secure defaults (no external dependencies):

- Open timeout: 30s, write: 60s, read: 120s
- Redirect limit: 5
- SSL verification: enabled (VERIFY_PEER)
- SSRF protection: redirects to private/reserved IPs are blocked
- Scheme downgrade protection: HTTPS-to-HTTP redirects are blocked
- DNS resolution timeout: 5s (blocks redirect if resolution fails)

Configure via `client.http` (returns a `WSDL::HTTPAdapter::Config`):

```ruby
client = WSDL::Client.new(wsdl)
client.http.open_timeout = 10
client.http.read_timeout = 60
client.http.ca_file = '/path/to/ca-bundle.crt'
client.http.cert = OpenSSL::X509::Certificate.new(File.read('/path/to/client.crt'))
client.http.key = OpenSSL::PKey::RSA.new(File.read('/path/to/client.key'))
```

## See also

- [Getting Started](../getting_started.md)
- [Error Hierarchy](../reference/errors.md)
- [Resolving Imports](resolving-imports.md)
- [Strict Schema Fixture Matrix](../reference/strict-schema-fixture-matrix.md)
- [Specifications and References](../reference/specifications.md)
