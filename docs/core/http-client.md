# HTTP Client

The HTTP client handles WSDL/schema fetching (`get`) and SOAP operation calls (`post`). The built-in `WSDL::HTTP::Client` uses Ruby's stdlib `net/http` with no external dependencies and applies secure defaults out of the box.

## Secure Defaults

| Setting | Default | Purpose |
|---------|---------|---------|
| Open timeout | 30s | Prevents hangs during TCP connection |
| Write timeout | 60s | Prevents hangs during request send |
| Read timeout | 120s | Prevents hangs waiting for response |
| Redirect limit | 5 | Prevents redirect loops |
| SSL verification | `VERIFY_PEER` | Prevents man-in-the-middle attacks |
| DNS resolution timeout | 5s per hop | Prevents hangs on slow DNS during redirects |

## Configuration

Configure via `client.http`, which returns a `WSDL::HTTP::Config`:

```ruby
definition = WSDL.parse('http://example.com/service?wsdl')
client = WSDL::Client.new(definition)

# Timeouts
client.http.open_timeout = 10
client.http.read_timeout = 60

# SSL
client.http.ca_file = '/path/to/ca-bundle.crt'
client.http.ca_path = '/path/to/ca-dir/'
client.http.min_version = :TLS1_2

# Mutual TLS (client certificate authentication)
client.http.cert = OpenSSL::X509::Certificate.new(File.read('/path/to/client.crt'))
client.http.key = OpenSSL::PKey::RSA.new(File.read('/path/to/client.key'))

# Redirects
client.http.max_redirects = 3
```

### Disabling SSL verification

SSL verification can be disabled for development/testing. A warning is logged on the first request.

```ruby
client.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
```

> **Warning:** Never disable SSL verification in production. It makes connections vulnerable to man-in-the-middle attacks.

## Redirect Following

The client automatically follows HTTP redirects (301, 302, 303, 307, 308) up to `max_redirects` hops. Every redirect target is validated before the connection is made.

### Method handling

| Status | Behavior |
|--------|----------|
| 301, 302, 303 | Method changes to GET, body and headers are dropped |
| 307, 308 | Method, body, and headers are preserved |

### Cross-origin header stripping

On 307/308 redirects to a different origin (different host or explicit port), sensitive headers are automatically stripped to prevent credential leakage:

- `Authorization`
- `Cookie`
- `Proxy-Authorization`

Same-host TLS upgrades (HTTP to HTTPS) are not considered cross-origin, so credentials are preserved.

### Scheme validation

Only `http` and `https` schemes are allowed. Redirects to other schemes (`file`, `ftp`, `gopher`, `data`, etc.) are blocked to prevent local file access and protocol smuggling. HTTPS-to-HTTP downgrades are also blocked to prevent credential exposure over plaintext.

## SSRF Protection

Server-Side Request Forgery (SSRF) attacks exploit server-initiated HTTP requests to access internal resources. A malicious WSDL endpoint could redirect to cloud metadata services (`169.254.169.254`), loopback interfaces (`127.0.0.1`), or private networks (`10.x.x.x`).

These checks apply to **redirect targets only**, not the initial request URL. The caller controls the initial URL and is responsible for its safety. The threat model is an attacker-controlled redirect from an otherwise legitimate endpoint.

The client blocks redirects to all IANA special-purpose address ranges:

### Blocked IPv4 ranges

| Range | Purpose | Reference |
|-------|---------|-----------|
| `0.0.0.0/8` | Current network | RFC 1122 |
| `10.0.0.0/8` | Private | RFC 1918 |
| `100.64.0.0/10` | Shared address space (CGNAT) | RFC 6598 |
| `127.0.0.0/8` | Loopback | RFC 1122 |
| `169.254.0.0/16` | Link-local | RFC 3927 |
| `172.16.0.0/12` | Private | RFC 1918 |
| `192.0.0.0/24` | IETF protocol assignments | RFC 6890 |
| `192.0.2.0/24` | Documentation (TEST-NET-1) | RFC 5737 |
| `192.88.99.0/24` | 6to4 relay anycast | RFC 7526 |
| `192.168.0.0/16` | Private | RFC 1918 |
| `198.18.0.0/15` | Benchmarking | RFC 2544 |
| `198.51.100.0/24` | Documentation (TEST-NET-2) | RFC 5737 |
| `203.0.113.0/24` | Documentation (TEST-NET-3) | RFC 5737 |
| `240.0.0.0/4` | Reserved for future use | RFC 1112 |
| `255.255.255.255/32` | Broadcast | — |

### Blocked IPv6 ranges

| Range | Purpose | Reference |
|-------|---------|-----------|
| `::/128` | Unspecified | RFC 4291 |
| `::1/128` | Loopback | RFC 4291 |
| `64:ff9b::/96` | NAT64 well-known prefix | RFC 6052 |
| `64:ff9b:1::/48` | NAT64 local-use prefix | RFC 8215 |
| `100::/64` | Discard-only | RFC 6666 |
| `2001::/32` | Teredo tunneling | RFC 4380 |
| `2001:10::/28` | ORCHID | RFC 4843 |
| `2001:db8::/32` | Documentation | RFC 3849 |
| `2002::/16` | 6to4 | RFC 3056 |
| `fc00::/7` | Unique local | RFC 4193 |
| `fe80::/10` | Link-local | RFC 4291 |

### IPv6 bypass prevention

Several IPv6 representations can encode IPv4 addresses to bypass range checks. The client normalizes these before validation:

- **IPv4-mapped** (`::ffff:127.0.0.1`) — normalized to native IPv4 via `IPAddr#native`
- **IPv4-compatible** (`::127.0.0.1`) — normalized to native IPv4 via `IPAddr#native`
- **6to4** (`2002:c0a8:0101::`) — blocked by the `2002::/16` range, which covers any embedded private IPv4
- **IPv6 zone IDs** (`fe80::1%eth0`) — zone ID stripped before parsing to prevent `IPAddr` rejection

### DNS rebinding prevention

When a redirect targets a hostname (not an IP literal), the client:

1. Resolves the hostname via DNS with a 5-second timeout
2. Validates **all** returned addresses against the blocked ranges
3. Pins the validated IP on the `Net::HTTP` connection via `ipaddr=`

IP pinning closes the TOCTOU (time-of-check-time-of-use) gap where an attacker's DNS server returns a safe address during validation but a private address when `Net::HTTP` makes its own resolution for the actual connection.

If DNS resolution fails for any reason (timeout, NXDOMAIN, network error), the redirect is blocked — the target's safety cannot be verified.

### Timeout considerations

DNS resolution timeout applies per redirect hop. Worst-case DNS latency across a full redirect chain is `max_redirects × 5s` (default: 25 seconds), on top of connection and read timeouts. This bounds the total delay even if an attacker serves a chain of redirects to slow-DNS hostnames.

## Gzip Bomb Protection

The client sets `Accept-Encoding: identity` to disable transparent gzip decompression. Without this, a small compressed response could decompress into gigabytes in memory before document size limits can be checked. User-provided `Accept-Encoding` headers override this default.

## Custom Clients

Replace the built-in client when you need features like connection pooling, proxy support, or instrumentation.

### Client interface

Custom clients must implement:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get` | `get(url) → HTTP::Response` | Fetch WSDL and schema documents |
| `post` | `post(url, headers, body) → HTTP::Response` | Send SOAP requests |
| `config` | `config → Object` | Configuration object exposed via `client.http` |

### Example

```ruby
class MyHTTPClient
  def initialize
    @connection = Faraday.new
  end

  # Expose the Faraday connection for user configuration
  # (e.g. client.http.options.timeout = 30).
  attr_reader :connection
  alias config connection

  def get(url)
    resp = @connection.get(url)
    WSDL::HTTP::Response.new(status: resp.status, headers: resp.headers, body: resp.body)
  end

  def post(url, headers, body)
    resp = @connection.post(url, body, headers)
    WSDL::HTTP::Response.new(status: resp.status, headers: resp.headers, body: resp.body)
  end
end
```

### Setting the client

```ruby
# Global (all new clients)
WSDL.http_client = MyHTTPClient

# Per-client (use on both parse and client for full control)
http = MyHTTPClient.new
definition = WSDL.parse('http://example.com/service?wsdl', http:)
client = WSDL::Client.new(definition, http:)
```

> **Note:** Custom clients are responsible for their own redirect handling and SSRF protection. The built-in protections described above only apply to `WSDL::HTTP::Client`.

## See also

- [Getting Started](../getting_started.md)
- [Configuration](configuration.md)
- [Resolving Imports](resolving-imports.md)
- [Error Hierarchy](../reference/errors.md)
- [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
