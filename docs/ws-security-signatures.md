# X.509 Certificate Signatures

This guide covers digital signatures using X.509 certificates for message integrity and non-repudiation.

> **Quick Links:** [Main WS-Security Guide](ws-security.md) | [UsernameToken](ws-security-username-token.md) | [Troubleshooting](ws-security-troubleshooting.md)

## Overview

X.509 signing provides the strongest authentication option in WS-Security:

- **Message Integrity** — Detects any tampering with signed content
- **Non-repudiation** — Cryptographic proof of sender identity
- **Configurable Algorithms** — SHA-256 (default), SHA-512, or SHA-1 (legacy)
- **Response Verification** — Validate that responses are properly signed

## Basic Usage

```ruby
operation.security.signature(
  certificate: File.read('cert.pem'),
  private_key: File.read('key.pem')
)
```

## Loading Certificates

Certificates and keys can be loaded from PEM files or provided as OpenSSL objects:

```ruby
# From PEM files
cert = File.read('/path/to/certificate.pem')
key = File.read('/path/to/private_key.pem')

operation.security.signature(
  certificate: cert,
  private_key: key
)

# From OpenSSL objects
cert = OpenSSL::X509::Certificate.new(File.read('/path/to/certificate.pem'))
key = OpenSSL::PKey::RSA.new(File.read('/path/to/private_key.pem'))

operation.security.signature(
  certificate: cert,
  private_key: key
)
```

## Encrypted Private Keys

If your private key is encrypted, provide the password:

```ruby
operation.security.signature(
  certificate: File.read('cert.pem'),
  private_key: File.read('encrypted_key.pem'),
  key_password: 'secret'
)
```

## Digest Algorithms

The library supports multiple digest algorithms:

| Algorithm | Option | Recommendation |
|-----------|--------|----------------|
| SHA-256 | `:sha256` | **Default, recommended** |
| SHA-384 | `:sha384` | Stronger option |
| SHA-512 | `:sha512` | Strongest, use for long-term security |
| SHA-224 | `:sha224` | Optional, rarely used |
| SHA-1 | `:sha1` | Legacy only, **not recommended** |

```ruby
# SHA-256 (default, recommended)
operation.security.signature(
  certificate: cert,
  private_key: key,
  digest_algorithm: :sha256
)

# SHA-512 (stronger)
operation.security.signature(
  certificate: cert,
  private_key: key,
  digest_algorithm: :sha512
)

# SHA-1 (legacy, not recommended for new implementations)
operation.security.signature(
  certificate: cert,
  private_key: key,
  digest_algorithm: :sha1
)
```

## Signature Algorithms

The library supports the following signature algorithms for response verification:

| Family | Algorithms | Notes |
|--------|------------|-------|
| **RSA** | RSA-SHA1, RSA-SHA224, RSA-SHA256, RSA-SHA384, RSA-SHA512 | Most common |
| **ECDSA** | ECDSA-SHA1, ECDSA-SHA224, ECDSA-SHA256, ECDSA-SHA384, ECDSA-SHA512 | Required by XML Signature 1.1 |
| **DSA** | DSA-SHA1, DSA-SHA256 | Legacy support |

## Algorithm Security

The library implements strict algorithm validation to prevent algorithm confusion attacks:

- **Unknown algorithms are rejected** — If a response contains an unrecognized algorithm URI, verification fails with `UnsupportedAlgorithmError`
- **No silent fallbacks** — The library never silently defaults to a different algorithm
- **Clear error messages** — Errors include the unrecognized URI and algorithm type

This prevents attacks where an adversary modifies the algorithm URI to cause verification with unintended parameters.

```ruby
begin
  response.security.verify_signature!
rescue WSDL::UnsupportedAlgorithmError => e
  puts "Unknown algorithm: #{e.algorithm_uri}"
  puts "Algorithm type: #{e.algorithm_type}"  # :digest, :signature, or :canonicalization
end
```

## Controlling What Gets Signed

By default, both the SOAP body and timestamp (if present) are signed.

```ruby
# Sign only the body
operation.security.signature(
  certificate: cert,
  private_key: key,
  sign_body: true,
  sign_timestamp: false
)

# Sign only the timestamp
operation.security.signature(
  certificate: cert,
  private_key: key,
  sign_body: false,
  sign_timestamp: true
)
```

## Key Reference Methods

When you sign a message, the recipient needs to know which certificate was used. The library supports three methods:

### BinarySecurityToken (Default)

Embeds the full certificate in the message. Self-contained but larger messages:

```ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  key_reference: :binary_security_token
)
```

**When to use:** General purpose, when the recipient doesn't have your certificate.

### IssuerSerial

References the certificate by issuer DN and serial number. Smaller messages, but the recipient must already have the certificate:

```ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  key_reference: :issuer_serial
)
```

**When to use:** Enterprise environments with centralized certificate management where both parties have pre-shared certificates.

### SubjectKeyIdentifier

References the certificate by its Subject Key Identifier extension. The certificate must have this extension:

```ruby
operation.security.signature(
  certificate: cert,  # Must have SKI extension
  private_key: key,
  key_reference: :subject_key_identifier
)
```

**When to use:** Similar to IssuerSerial, but uses a more stable identifier that doesn't change if the certificate is re-issued.

## Signing WS-Addressing Headers

If your service uses WS-Addressing, sign those headers to prevent routing attacks:

```ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  sign_addressing: true
)
```

**Why use this?** WS-Addressing headers like `wsa:To` and `wsa:Action` specify where the message goes and what operation to invoke. Without signing, an attacker could modify these headers to redirect your signed message to a malicious endpoint.

When enabled, the following headers are signed if present:

| Header | Purpose |
|--------|---------|
| `wsa:To` | The destination endpoint |
| `wsa:From` | The source endpoint |
| `wsa:ReplyTo` | Where to send the reply |
| `wsa:FaultTo` | Where to send faults |
| `wsa:Action` | The operation being invoked |
| `wsa:MessageID` | Unique message identifier |
| `wsa:RelatesTo` | Correlation to another message |

## Explicit Namespace Prefixes

Some SOAP servers have strict XML parsers that only accept explicit namespace prefixes:

```ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  explicit_namespace_prefixes: true
)
```

**When to use:** If you're getting XML parsing errors from the server, or the server documentation specifies a particular XML format.

This changes the output from:

```xml
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  <SignedInfo>...</SignedInfo>
</Signature>
```

To:

```xml
<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
  <ds:SignedInfo>...</ds:SignedInfo>
</ds:Signature>
```

## Timestamps

Timestamps help prevent replay attacks. When combined with signatures, the timestamp should be signed:

```ruby
operation.security
  .timestamp(expires_in: 300)  # 5-minute expiration
  .signature(
    certificate: cert,
    private_key: key,
    sign_timestamp: true  # Default when timestamp is present
  )
```

### Timestamp Options

```ruby
# Default 5-minute expiration
operation.security.timestamp

# Custom expiration (10 minutes)
operation.security.timestamp(expires_in: 600)

# Explicit times
operation.security.timestamp(
  created_at: Time.now.utc,
  expires_at: Time.now.utc + 900  # 15 minutes
)
```

This produces XML like:

```xml
<wsu:Timestamp wsu:Id="Timestamp-abc123">
  <wsu:Created>2025-01-15T12:00:00Z</wsu:Created>
  <wsu:Expires>2025-01-15T12:05:00Z</wsu:Expires>
</wsu:Timestamp>
```

---

# Response Signature Verification

For high-security scenarios, verify that responses from the server are properly signed.

## Enabling Verification

```ruby
# Strict verification (signature required, system trust store by default)
operation.security.verify_response

response = operation.call

if response.security.signature_valid?
  # Safe to trust the response
  puts response.body
else
  puts "Verification failed: #{response.security.errors}"
end
```

Verification mode is explicit:

```ruby
# Strict: signature must be present and valid
operation.security.verify_response(mode: :required)

# Opportunistic: verify only when response contains a signature
operation.security.verify_response(mode: :if_present)

# Disable enforcement (response still exposes response.security.* checks)
operation.security.verify_response(mode: :disabled)
```

## Checking Signature Presence

```ruby
if response.security.signature_present?
  puts "Response is signed"
  puts "Signed elements: #{response.security.signed_elements}"
  # => ["Body", "Timestamp"]
else
  puts "Response is not signed"
end
```

## Strict Verification

Use `verify_signature!` to raise an error if signature verification fails:

```ruby
begin
  response.security.verify_signature!
  # Process trusted response
rescue WSDL::SignatureVerificationError => e
  log_security_event("Untrusted response: #{e.message}")
end
```

For combined signature and timestamp verification, use `verify!`:

```ruby
begin
  response.security.verify!
  # Process trusted and fresh response
rescue WSDL::SignatureVerificationError => e
  log_security_event("Signature error: #{e.message}")
rescue WSDL::TimestampValidationError => e
  log_security_event("Timestamp error: #{e.message}")
end
```

## Verification Details

Inspect verification results via the security context:

```ruby
response.security.signature_valid?      # => true/false
response.security.signature_present?    # => true/false
response.security.signed_elements       # => ["Body", "Timestamp"]
response.security.signed_element_ids    # => ["Body-abc123", "Timestamp-xyz"]
response.security.signature_algorithm   # => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
response.security.digest_algorithm      # => "http://www.w3.org/2001/04/xmlenc#sha256"
response.security.signing_certificate   # => OpenSSL::X509::Certificate
response.security.errors                # => ["Digest mismatch for #Body-123"]
```

## Providing a Certificate

If the response doesn't include the certificate (using IssuerSerial or SKI reference), provide it when creating a `SecurityContext` directly:

```ruby
server_cert = OpenSSL::X509::Certificate.new(File.read('server.pem'))
context = WSDL::Response::SecurityContext.new(document, certificate: server_cert)
context.signature_valid?
```

---

## Certificate Validation

When verifying response signatures, you can validate the signing certificate's validity period and trust chain.

### Validity Period Checking (Default: Enabled)

By default, the library checks that the signing certificate is within its validity period (not expired and not before its start date). This catches:

- Expired certificates from decommissioned systems
- Certificates that aren't valid yet (clock skew or future-dated certs)

```ruby
# Signature is required by default when verify_response is called
operation.security.verify_response(mode: :required)

# Explicitly disable validity checking (not recommended)
operation.security.verify_response(check_validity: false)
```

### Trust Store Validation (Optional)

For higher security, validate the certificate chain against trusted Certificate Authorities:

```ruby
# Use system CA certificates (most common)
operation.security.verify_response(trust_store: :system)

# Use a specific CA bundle file
operation.security.verify_response(trust_store: '/etc/ssl/certs/ca-certificates.crt')

# Use a directory of CA certificates
operation.security.verify_response(trust_store: '/etc/ssl/certs/')

# Use specific CA certificates
ca = OpenSSL::X509::Certificate.new(File.read('company-ca.pem'))
operation.security.verify_response(trust_store: [ca])

# Use a pre-configured OpenSSL store
store = OpenSSL::X509::Store.new
store.add_file('ca-bundle.crt')
operation.security.verify_response(trust_store: store)
```

### Trust Store Options

| Option | Description |
|--------|-------------|
| `:system` | System default CA certificates (e.g., `/etc/ssl/certs`) |
| `String` (file) | Path to CA bundle file (`.crt`, `.pem`) |
| `String` (dir) | Path to directory containing CA certificates |
| `Array` | Array of `OpenSSL::X509::Certificate` objects |
| `OpenSSL::X509::Store` | Pre-configured certificate store for advanced use cases |

### Timestamp Validation Options

Timestamp validation is enabled by default to prevent replay attacks:

```ruby
# Custom clock skew tolerance (default: 300 seconds / 5 minutes)
operation.security.verify_response(clock_skew: 600)  # 10 minutes

# Disable timestamp validation (not recommended)
operation.security.verify_response(validate_timestamp: false)
```

| Option | Default | Description |
|--------|---------|-------------|
| `validate_timestamp` | `true` | Whether to validate response timestamp freshness |
| `clock_skew` | `300` | Clock skew tolerance in seconds (5 minutes per WS-I BSP guidance) |

These options are internally mapped to a `ResponseVerification::Options` Data class with nested `certificate` and `timestamp` configuration groups.

### Full Example with Chain Validation

```ruby
operation.security
  .timestamp(expires_in: 300)
  .signature(
    certificate: cert,
    private_key: key,
    digest_algorithm: :sha256
  )
  .verify_response(trust_store: :system, clock_skew: 600)

response = operation.call

if response.security.valid?
  # Certificate is valid, signed by a trusted CA, and timestamp is fresh
  puts response.body
else
  response.security.errors.each do |error|
    puts "Error: #{error}"
  end
end
```

### All verify_response Options

| Option | Default | Description |
|--------|---------|-------------|
| `mode` | `:required` | Enforcement mode: `:required`, `:if_present`, `:disabled` |
| `trust_store` | `:system` in `:required` mode, otherwise `nil` | Trust store for certificate chain validation |
| `check_validity` | `true` | Check certificate validity period (not_before/not_after) |
| `validate_timestamp` | `true` | Validate response timestamp freshness |
| `clock_skew` | `300` | Clock skew tolerance in seconds for timestamp validation |

Internally, these options are organized into a `ResponseVerification::Options` structure:

```ruby
# Internal structure (for advanced usage)
verification = WSDL::Security::ResponseVerification::Options.new(
  certificate: WSDL::Security::ResponseVerification::Certificate.new(
    trust_store: :system,
    verify_not_expired: true  # maps to check_validity
  ),
  timestamp: WSDL::Security::ResponseVerification::Timestamp.new(
    validate: true,           # maps to validate_timestamp
    tolerance_seconds: 300    # maps to clock_skew
  )
)
```

### When to Use Trust Store Validation

**Recommended when:**
- Communicating with external services
- Compliance requirements (PCI-DSS, HIPAA, etc.)
- You don't control the server certificate

---

## Timestamp Validation

Timestamps help prevent replay attacks by ensuring that responses are fresh. When combined with signatures, the timestamp should be signed to prevent tampering.

### How It Works

Timestamp validation checks:

1. **Expires** — The message must not have expired (accounting for clock skew)
2. **Created** — The creation time must not be too far in the future (clock skew protection)

Per the WS-Security specification, timestamps are optional. When present, they are validated by default.

### Default Behavior

Timestamp validation is **enabled by default** with a 5-minute clock skew tolerance:

```ruby
response = operation.call

# Validates signature AND timestamp by default
if response.security.valid?
  puts "Response is signed and fresh"
end

# Or use verify! for strict checking
response.security.verify!  # raises on failure
```

### Checking Timestamp Details

```ruby
# Check if timestamp is present
response.security.timestamp_present?  # => true/false

# Check if timestamp is valid (fresh)
response.security.timestamp_valid?    # => true/false

# Get parsed timestamp values
response.security.timestamp
# => { created_at: 2025-01-15 12:00:00 UTC, expires_at: 2025-01-15 12:05:00 UTC }

# Strict verification
response.security.verify_timestamp!   # raises TimestampValidationError on failure
```

### Configuring Clock Skew

Clock skew tolerance accounts for unsynchronized clocks between sender and receiver. The default is 300 seconds (5 minutes), per WS-I BSP guidance:

```ruby
# Configure via operation security (recommended)
operation.security.verify_response(clock_skew: 600)  # 10 minutes tolerance

# Or with stricter tolerance for high-security scenarios
operation.security.verify_response(clock_skew: 60)   # 1 minute tolerance
```

### Disabling Timestamp Validation

For backward compatibility or when timestamps are not used:

```ruby
# Configure via operation security
operation.security.verify_response(validate_timestamp: false)

response = operation.call

# Now only signature is validated
response.security.valid?  # only checks signature
```

### Error Handling

```ruby
begin
  response.security.verify!
rescue WSDL::SignatureVerificationError => e
  # Signature is invalid or missing
  puts "Signature error: #{e.message}"
rescue WSDL::TimestampValidationError => e
  # Timestamp has expired or is too far in the future
  puts "Timestamp error: #{e.message}"
end
```

### Why Timestamp Validation Matters

Without timestamp validation, an attacker can:

1. Capture a valid signed response
2. Store it indefinitely
3. Replay it later to the client

With timestamp validation, replayed messages are rejected because their timestamps have expired.

> **Best Practice:** Always sign the timestamp element to prevent attackers from modifying it.

**May skip when:**
- Internal services with pre-shared certificates
- Development/testing environments
- You provide the expected certificate explicitly via `verify_certificate`

### Certificate Validation Error Messages

| Error | Meaning |
|-------|---------|
| `Certificate has expired (expired ...)` | Certificate's `notAfter` date has passed |
| `Certificate is not yet valid (valid from ...)` | Certificate's `notBefore` date is in the future |
| `Certificate chain validation failed: self signed certificate` | Self-signed cert rejected by trust store |
| `Certificate chain validation failed: unable to get local issuer certificate` | CA not found in trust store |

---

## XML Signature Wrapping (XSW) Protection

XML Signature Wrapping attacks attempt to manipulate signed documents by moving signed elements or injecting malicious content while keeping signatures technically valid. The library includes built-in protections against these attacks.

### How XSW Attacks Work

1. **Attacker intercepts** a legitimately signed SOAP response
2. **Moves the signed element** (e.g., Body) to a different location in the document
3. **Injects malicious content** at the original location
4. **Signature validates** because the signed element still exists with correct digest
5. **Application processes** the malicious content instead of the signed content

### Built-in Protections

The verifier implements multiple layers of defense recommended by the [W3C XML Signature Best Practices](https://www.w3.org/TR/xmldsig-bestpractices/):

#### Duplicate ID Detection

Documents with duplicate `wsu:Id`, `Id`, or `xml:id` attributes are rejected. Attackers often inject elements with the same ID as signed elements.

```ruby
# This attack pattern is detected and rejected:
# <soap:Body wsu:Id="Body-123">Malicious</soap:Body>  <!-- Injected -->
# <soap:Body wsu:Id="Body-123">Legitimate</soap:Body> <!-- Original signed -->
```

**Error:** `Duplicate element IDs detected (possible signature wrapping attack): Body-123`

#### Signature Location Validation

The `ds:Signature` element must be within the `wsse:Security` header as required by WS-Security. Signatures elsewhere in the document are rejected.

**Error:** `Signature element must be within wsse:Security header (possible signature wrapping attack)`

#### Element Position Validation

Signed elements must be in their expected structural positions:

| Element | Expected Position |
|---------|-------------------|
| `soap:Body` | Direct child of `soap:Envelope` |
| `wsu:Timestamp` | Within `wsse:Security` header |
| WS-Addressing headers | Within `soap:Header` |

**Error examples:**
- `Body element must be a direct child of soap:Envelope (possible signature wrapping attack)`
- `Timestamp element must be within wsse:Security header (possible signature wrapping attack)`

### Interpreting XSW Errors

When verification fails with a "signature wrapping attack" message, the document structure has been manipulated. **Do not trust the content.** These errors indicate:

1. A potential attack in progress
2. A malformed document from a buggy implementation
3. An incompatible security configuration

In all cases, reject the message and investigate the source.

### Example Attack Scenario

```xml
<!-- ATTACK: Body moved to wrapper, malicious content in standard position -->
<soap:Envelope>
  <soap:Header>
    <wsse:Security>
      <ds:Signature>
        <ds:Reference URI="#Body-123"/>  <!-- Points to wrapped body -->
      </ds:Signature>
    </wsse:Security>
  </soap:Header>
  <!-- Malicious content (application processes this) -->
  <soap:Body>
    <TransferResponse><amount>1000000</amount></TransferResponse>
  </soap:Body>
  <!-- Original signed content (verifier validates this) -->
  <Wrapper>
    <soap:Body wsu:Id="Body-123">
      <TransferResponse><amount>10</amount></TransferResponse>
    </soap:Body>
  </Wrapper>
</soap:Envelope>
```

The library detects this attack because the signed `Body` element is not a direct child of `Envelope`.

---

## Best Practices

1. **Use SHA-256 or stronger** — SHA-1 is deprecated for signatures
2. **Sign timestamps** — Prevents replay attacks
3. **Protect private keys** — Use file permissions (`chmod 600`) and encrypted keys
4. **Use appropriate key sizes** — RSA 2048-bit minimum, 4096-bit recommended
5. **Rotate certificates** — Have a process for rotation before expiration
6. **Verify responses** — Enable `verify_response` for high-security scenarios
7. **Sign WS-Addressing headers** — Prevents routing attacks

## Related Documentation

- [Main WS-Security Guide](ws-security.md) — Overview and choosing authentication methods
- [UsernameToken Authentication](ws-security-username-token.md) — Password-based authentication
- [Troubleshooting](ws-security-troubleshooting.md) — Common issues and solutions
