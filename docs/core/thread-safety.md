# Thread Safety

This page describes which objects are safe to share across threads and which must be created per-thread or per-request.

## Safe to share

These objects are frozen after construction and carry no mutable state:

| Object | Why it's safe |
|--------|---------------|
| `Definition` | Deep-frozen on construction (`deep_freeze` + `freeze`) |
| `Config` | Frozen after construction |
| `Limits` | Frozen after construction |
| `Strictness` | Frozen after construction |
| `Client` | Core state is frozen; HTTP config is mutable (see below) |

### Client

`Client` is thread-safe after construction. Its instance state is either frozen (`Definition`, `Config`, `services` hash) or only read (the HTTP client reference). Multiple threads can safely call `#services`, `#operations`, `#service_name`, and `#operation` concurrently.

```ruby
# Safe: share a single client across threads
definition = WSDL.parse('http://example.com/service?wsdl')
client = WSDL::Client.new(definition)

threads = 4.times.map do
  Thread.new { client.operation('GetOrder') }
end
threads.each(&:join)
```

## Not safe to share

These objects carry mutable per-request state and must not be shared across threads:

| Object | Why it's not safe | What to do |
|--------|-------------------|------------|
| `Operation` | Mutable state from e.g. `prepare` / `reset!` / `invoke` | Create one per thread or per request |
| `Response` | Lazy-parsed body, header, doc, and more | Use only in the thread that received it |
| `HTTP::Config` | Mutable `attr_accessor` settings (timeouts, SSL) | Configure before spawning threads |

### Operation

`Client#operation` returns a new `Operation` instance on every call, so the typical pattern is naturally thread-safe:

```ruby
# Safe: each thread gets its own Operation
Thread.new do
  op = client.operation('GetOrder')
  op.prepare { tag('GetOrder') { tag('id', 123) } }
  response = op.invoke
end
```

Do not share a single `Operation` instance across threads.

### HTTP::Config

`client.http` is a convenience accessor that returns the HTTP client's mutable `Config` object (timeouts, SSL settings), not the client itself. Configure it before sharing the client:

```ruby
client = WSDL::Client.new(definition)
client.http.open_timeout = 10
client.http.read_timeout = 60

# Now safe to share `client` across threads
```

Mutating `client.http` after threads are running creates a data race.

## Global settings

`WSDL.http_client` and `WSDL.logger` are module-level globals. Set them once at boot time (e.g., in a Rails initializer) before creating any clients or spawning threads:

```ruby
# config/initializers/wsdl.rb
WSDL.http_client = MyHTTPClient
WSDL.logger = Rails.logger
```

See [Configuration](configuration.md#global-defaults) for details.

## See also

- [Configuration](configuration.md)
- [HTTP Client](http-client.md)
- [Getting Started](../getting_started.md)
