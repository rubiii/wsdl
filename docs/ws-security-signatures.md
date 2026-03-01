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
| SHA-512 | `:sha512` | Stronger, use for long-term security |
| SHA-1 | `:sha1` | Legacy only, not recommended |

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
operation.security.verify_response = true

response = operation.call

if response.signature_valid?
  # Safe to trust the response
  puts response.body
else
  puts "Verification failed: #{response.signature_errors}"
end
```

## Checking Signature Presence

```ruby
if response.signature_present?
  puts "Response is signed"
  puts "Signed elements: #{response.signed_elements}"
  # => ["Body", "Timestamp"]
else
  puts "Response is not signed"
end
```

## Strict Verification

Use `verify_signature!` to raise an error if verification fails:

```ruby
begin
  response.verify_signature!
  # Process trusted response
rescue WSDL::SignatureVerificationError => e
  log_security_event("Untrusted response: #{e.message}")
end
```

## Verification Details

Inspect verification results:

```ruby
response.signature_valid?      # => true/false
response.signature_present?    # => true/false
response.signed_elements       # => ["Body", "Timestamp"]
response.signed_element_ids    # => ["Body-abc123", "Timestamp-xyz"]
response.signature_algorithm   # => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
response.digest_algorithm      # => "http://www.w3.org/2001/04/xmlenc#sha256"
response.signing_certificate   # => OpenSSL::X509::Certificate
response.signature_errors      # => ["Digest mismatch for #Body-123"]
```

## Providing a Certificate

If the response doesn't include the certificate (using IssuerSerial or SKI reference), provide it:

```ruby
server_cert = OpenSSL::X509::Certificate.new(File.read('server.pem'))
response = WSDL::Response.new(xml, verify_certificate: server_cert)
response.signature_valid?
```

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