# WS-Security

This guide covers the WS-Security (Web Services Security) features available in the WSDL library.

## Overview

WS-Security provides a standard way to secure SOAP messages through:

- **Authentication** - UsernameToken with plain text or digest passwords
- **Message Integrity** - Timestamps and X.509 digital signatures
- **Replay Protection** - Nonces and expiration times
- **Response Verification** - Validate signed responses from the server

The library implements the following OASIS specifications:

- [SOAP Message Security 1.1](https://docs.oasis-open.org/wss/v1.1/)
- [UsernameToken Profile 1.1](https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf)
- [X.509 Token Profile 1.1](https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf)

## XML Parsing Security

The library includes comprehensive protection against XML-based attacks. All XML parsing uses secure defaults that protect against common vulnerabilities.

### Protections Enabled by Default

- **XXE (XML External Entity) Prevention** — External entities are not loaded, preventing attackers from reading local files or making network requests through XML parsing.

- **SSRF (Server-Side Request Forgery) Prevention** — Network access during XML parsing is blocked via the `NONET` option, preventing the parser from making outbound requests.

- **DTD Attack Prevention** — External DTD loading is disabled, preventing DTD-based attacks.

- **Entity Expansion Limits** — Internal entity expansion is limited by libxml2's default limits, providing protection against Billion Laughs / XML bomb attacks.

### Security Errors

When libxml2 detects a security violation (such as an XML bomb or excessive nesting), the library raises `WSDL::XMLSecurityError`:

```ruby
begin
  doc = WSDL::XML::Parser.parse(untrusted_xml)
rescue WSDL::XMLSecurityError => e
  # Security attack blocked (entity amplification, excessive depth, etc.)
  logger.warn("XML attack blocked: #{e.message}")
  
  # Access the original Nokogiri error for debugging
  puts e.cause  # => #<Nokogiri::XML::SyntaxError: ...>
end
```

Since `XMLSecurityError` inherits from `WSDL::Error`, you can also rescue all WSDL errors together:

```ruby
begin
  client = WSDL::Client.new(untrusted_wsdl)
rescue WSDL::Error => e
  # Catches XMLSecurityError, SignatureVerificationError, etc.
  handle_error(e)
end
```

### Threat Detection and Logging

When parsing WSDL documents from remote sources, the library automatically scans for suspicious patterns and logs warnings:

```ruby
# Threats are automatically logged when parsing remote WSDLs
client = WSDL::Client.new('http://example.com/service?wsdl')
# If the WSDL contains suspicious patterns like DOCTYPE or ENTITY declarations,
# a warning is logged: "Potential XML attack detected: doctype, entity_declaration"
```

For custom XML parsing needs, you can use the secure parser directly:

```ruby
# Strict parsing (raises on malformed XML, XMLSecurityError on attacks)
doc = WSDL::XML::Parser.parse(xml_string)

# Relaxed parsing (tolerates malformed XML, still secure)
doc = WSDL::XML::Parser.parse_relaxed(xml_string)

# Parse with threat callback (for pre-parse pattern detection)
WSDL::XML::Parser.parse_untrusted(xml_string) do |threats|
  if threats.include?(:external_reference)
    raise WSDL::XMLSecurityError, "External references not allowed"
  end
end

# Parse with automatic logging
doc = WSDL::XML::Parser.parse_with_logging(xml_string, logger)
```

### Detected Threat Types

The threat detection system identifies:

| Threat | Description |
|--------|-------------|
| `:doctype` | DOCTYPE declaration (often used in XXE attacks) |
| `:entity_declaration` | ENTITY definitions (used to define XXE payloads) |
| `:external_reference` | SYSTEM or PUBLIC identifiers (external resource access) |
| `:parameter_entity` | Parameter entity references (`%entity;`) |
| `:deep_nesting` | Excessive tag nesting (potential DoS) |
| `:large_attribute` | Very long attribute values (potential DoS) |

## Basic Usage

WS-Security is configured on individual operations through the `security` method:

``` ruby
client = WSDL::Client.new('http://example.com/service?wsdl')
operation = client.operation('Service', 'Port', 'Operation')

# Configure security
operation.security.username_token('user', 'secret')

# Set request body and call
operation.body = { GetOrder: { orderId: 123 } }
response = operation.call
```

The security configuration is fluent, allowing method chaining:

``` ruby
operation.security
  .timestamp(expires_in: 300)
  .username_token('user', 'secret', digest: true)
```

## UsernameToken Authentication

UsernameToken provides username/password authentication for SOAP services.

### Plain Text Password

The simplest form sends the password in plain text (should only be used over HTTPS):

``` ruby
operation.security.username_token('username', 'password')
```

This produces XML like:

``` xml
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
  <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
    <wsse:Username>username</wsse:Username>
    <wsse:Password Type="...#PasswordText">password</wsse:Password>
  </wsse:UsernameToken>
</wsse:Security>
```

### Digest Password

Digest mode hashes the password with a nonce and timestamp, preventing the plain text password from being transmitted:

``` ruby
operation.security.username_token('username', 'password', digest: true)
```

The digest is computed as: `Base64(SHA-1(nonce + created + password))`

> **Security Note:** The WS-Security UsernameToken specification mandates SHA-1 for password digests. While SHA-1 is considered cryptographically weak by modern standards, this is a protocol limitation. For stronger security, consider using X.509 certificate signatures instead of password-based authentication.

This produces XML like:

``` xml
<wsse:Security xmlns:wsse="...">
  <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
    <wsse:Username>username</wsse:Username>
    <wsse:Password Type="...#PasswordDigest">hashed_value</wsse:Password>
    <wsse:Nonce EncodingType="...#Base64Binary">random_nonce</wsse:Nonce>
    <wsu:Created>2025-01-15T12:00:00Z</wsu:Created>
  </wsse:UsernameToken>
</wsse:Security>
```

### Custom Timestamp

You can specify a custom creation timestamp:

``` ruby
operation.security.username_token(
  'username',
  'password',
  digest: true,
  created_at: Time.utc(2025, 1, 15, 12, 0, 0)
)
```

## Timestamps

Timestamps help prevent replay attacks by specifying when a message was created and when it expires.

### Basic Timestamp

Add a timestamp with the default 5-minute expiration:

``` ruby
operation.security.timestamp
```

### Custom Expiration

Specify a custom expiration time in seconds:

``` ruby
# 10-minute expiration
operation.security.timestamp(expires_in: 600)
```

### Explicit Times

Provide explicit creation and expiration times:

``` ruby
operation.security.timestamp(
  created_at: Time.now.utc,
  expires_at: Time.now.utc + 900  # 15 minutes
)
```

This produces XML like:

``` xml
<wsse:Security xmlns:wsse="...">
  <wsu:Timestamp wsu:Id="Timestamp-abc123">
    <wsu:Created>2025-01-15T12:00:00Z</wsu:Created>
    <wsu:Expires>2025-01-15T12:15:00Z</wsu:Expires>
  </wsu:Timestamp>
</wsse:Security>
```

## X.509 Certificate Signing

X.509 signing provides message integrity and non-repudiation by digitally signing portions of the SOAP message.

### Loading Certificates

Certificates and keys can be loaded from PEM files or provided as OpenSSL objects:

``` ruby
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

### Encrypted Private Keys

If your private key is encrypted, provide the password:

``` ruby
operation.security.signature(
  certificate: File.read('cert.pem'),
  private_key: File.read('encrypted_key.pem'),
  key_password: 'secret'
)
```

### Digest Algorithms

The library supports multiple digest algorithms for signing:

``` ruby
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

### Controlling What Gets Signed

By default, both the SOAP body and timestamp (if present) are signed. You can control this:

``` ruby
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

### Key Reference Methods

When you sign a message, the recipient needs to know which certificate was used. The library supports three methods:

#### BinarySecurityToken (Default)

Embeds the full certificate in the message. Self-contained but larger messages:

``` ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  key_reference: :binary_security_token
)
```

#### IssuerSerial

References the certificate by issuer DN and serial number. Smaller messages, but the recipient must already have the certificate:

``` ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  key_reference: :issuer_serial
)
```

**When to use:** Enterprise environments with centralized certificate management where both parties have pre-shared certificates.

#### SubjectKeyIdentifier

References the certificate by its Subject Key Identifier extension. The certificate must have this extension:

``` ruby
operation.security.signature(
  certificate: cert,  # Must have SKI extension
  private_key: key,
  key_reference: :subject_key_identifier
)
```

**When to use:** Similar to IssuerSerial, but uses a more stable identifier that doesn't change if the certificate is re-issued.

### Signing WS-Addressing Headers

If your service uses WS-Addressing, you can sign those headers to prevent routing attacks:

``` ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  sign_addressing: true
)
```

**Why use this?** WS-Addressing headers like `wsa:To` and `wsa:Action` specify where the message goes and what operation to invoke. Without signing, an attacker could modify these headers to redirect your signed message to a malicious endpoint.

When enabled, the following WS-Addressing headers are signed if present:
- `wsa:To` - The destination endpoint
- `wsa:From` - The source endpoint
- `wsa:ReplyTo` - Where to send the reply
- `wsa:FaultTo` - Where to send faults
- `wsa:Action` - The operation being invoked
- `wsa:MessageID` - Unique message identifier
- `wsa:RelatesTo` - Correlation to another message

### Explicit Namespace Prefixes

Some SOAP servers have strict XML parsers that only accept explicit namespace prefixes:

``` ruby
operation.security.signature(
  certificate: cert,
  private_key: key,
  explicit_namespace_prefixes: true
)
```

**When to use:** If you're getting XML parsing errors from the server, or the server documentation specifies a particular XML format.

This changes the output from:

``` xml
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
  <SignedInfo>...</SignedInfo>
</Signature>
```

To:

``` xml
<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
  <ds:SignedInfo>...</ds:SignedInfo>
</ds:Signature>
```

## Response Signature Verification

For high-security scenarios, you can verify that responses from the server are properly signed:

### Enabling Verification

``` ruby
operation.security.verify_response = true
response = operation.call

if response.signature_valid?
  # Safe to trust the response
  puts response.body
else
  puts "Verification failed: #{response.signature_errors}"
end
```

### Checking Signature Presence

``` ruby
if response.signature_present?
  puts "Response is signed"
  puts "Signed elements: #{response.signed_elements}"
  # => ["Body", "Timestamp"]
else
  puts "Response is not signed"
end
```

### Strict Verification

Use `verify_signature!` to raise an error if verification fails:

``` ruby
begin
  response.verify_signature!
  # Process trusted response
rescue WSDL::SignatureVerificationError => e
  log_security_event("Untrusted response: #{e.message}")
end
```

### Verification Details

You can inspect verification results:

``` ruby
response.signature_valid?      # => true/false
response.signature_present?    # => true/false
response.signed_elements       # => ["Body", "Timestamp"]
response.signed_element_ids    # => ["Body-abc123", "Timestamp-xyz"]
response.signature_algorithm   # => "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
response.digest_algorithm      # => "http://www.w3.org/2001/04/xmlenc#sha256"
response.signing_certificate   # => OpenSSL::X509::Certificate
response.signature_errors      # => ["Digest mismatch for #Body-123"]
```

### Providing a Certificate

If the response doesn't include the certificate (using IssuerSerial or SKI reference), you can provide it:

``` ruby
server_cert = OpenSSL::X509::Certificate.new(File.read('server.pem'))
response = WSDL::Response.new(xml, verify_certificate: server_cert)
response.signature_valid?
```

## Combined Configuration

You can combine multiple security features:

``` ruby
# Full security configuration
operation.security
  .timestamp(expires_in: 300)
  .username_token('user', 'secret', digest: true)
  .signature(
    certificate: File.read('cert.pem'),
    private_key: File.read('key.pem'),
    digest_algorithm: :sha256,
    sign_addressing: true
  )

operation.security.verify_response = true
```

The order in which you call the methods doesn't matter - the library will produce the correct XML structure.

## Checking Configuration

You can inspect the current security configuration:

``` ruby
operation.security.configured?               # Any security configured?
operation.security.username_token?           # UsernameToken configured?
operation.security.timestamp?                # Timestamp configured?
operation.security.signature?                # X.509 signing configured?
operation.security.sign_addressing?          # WS-Addressing signing enabled?
operation.security.explicit_namespace_prefixes?  # Explicit prefixes enabled?
operation.security.verify_response?          # Response verification enabled?
operation.security.key_reference             # => :binary_security_token
```

## Clearing Configuration

To remove all security configuration:

``` ruby
operation.security.clear
```

## Previewing the Secured Request

Use `build` to see the complete SOAP envelope with security headers:

``` ruby
operation.security.username_token('user', 'secret')
operation.body = { GetOrder: { orderId: 123 } }

puts operation.build
```

## Complete Example

``` ruby
require 'wsdl'

# Load WSDL
client = WSDL::Client.new('https://secure-service.example.com/orders?wsdl')

# Get operation
operation = client.operation('OrderService', 'OrderServiceSoap', 'GetOrder')

# Configure security
operation.security
  .timestamp(expires_in: 300)
  .username_token('api_user', 'api_secret', digest: true)
  .signature(
    certificate: File.read('client_cert.pem'),
    private_key: File.read('client_key.pem'),
    digest_algorithm: :sha256,
    sign_addressing: true
  )

# Enable response verification
operation.security.verify_response = true

# Set request body
operation.body = {
  GetOrder: {
    orderId: 12345
  }
}

# Make the call
response = operation.call

# Verify and process response
if response.signature_valid?
  puts "Verified response from server"
  puts response.body
else
  raise "Response verification failed: #{response.signature_errors.join(', ')}"
end
```

## Security Best Practices

### Transport Security

1. **Always use HTTPS** — Even with WS-Security, transport-level encryption is essential. WS-Security provides message-level security (integrity, authentication), but HTTPS provides confidentiality and protects against network-level attacks.

2. **Verify SSL certificates** — Never disable SSL certificate verification in production:
   ```ruby
   # DANGEROUS - Never do this in production!
   # client.http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
   
   # Instead, configure proper CA certificates if needed:
   client.http.ssl_config.add_trust_ca('/path/to/ca-bundle.crt')
   ```

### Authentication

3. **Use digest passwords over plain text** — Digest mode prevents the password from being transmitted, even over HTTPS:
   ```ruby
   operation.security.username_token('user', 'secret', digest: true)
   ```

4. **Prefer X.509 signatures over passwords** — For high-security scenarios, X.509 certificate-based signing provides stronger authentication and non-repudiation than password-based authentication.

5. **Protect credentials** — Never hardcode passwords or private keys in source code. Use environment variables, secrets managers, or encrypted configuration files.

### Cryptographic Algorithms

6. **Use SHA-256 or stronger for signatures** — SHA-1 is considered weak; use SHA-256 (default) or SHA-512:
   ```ruby
   operation.security.signature(
     certificate: cert,
     private_key: key,
     digest_algorithm: :sha256  # or :sha512
   )
   ```

7. **Be aware of UsernameToken SHA-1 limitation** — The WS-Security specification mandates SHA-1 for password digests. This is a protocol limitation. For stronger security, use X.509 signatures.

### Key Management

8. **Protect private keys** — Store private keys encrypted with strong passwords and appropriate file permissions (e.g., `chmod 600`).

9. **Use appropriate key sizes** — RSA keys should be at least 2048 bits; 4096 bits recommended for long-term security.

10. **Rotate certificates regularly** — Have a process for certificate rotation before expiration.

### Message Security

11. **Use appropriate timestamp expiration** — Balance security (shorter expiration) with clock skew tolerance (longer expiration). Default is 5 minutes, which is reasonable for most scenarios.

12. **Verify response signatures** — For high-security scenarios, enable response verification:
    ```ruby
    operation.security.verify_response = true
    response = operation.call
    response.verify_signature!  # Raises if invalid
    ```

13. **Sign WS-Addressing headers** — If using WS-Addressing, sign those headers to prevent routing attacks:
    ```ruby
    operation.security.signature(
      certificate: cert,
      private_key: key,
      sign_addressing: true
    )
    ```

### Input Validation

14. **Trust the library's XML parsing** — The library's XML parser has secure defaults that protect against XXE, SSRF, and other XML attacks. Don't bypass it with direct Nokogiri calls on untrusted input.

15. **Validate WSDL sources** — Only load WSDL documents from trusted sources. While the library protects against XML attacks, a malicious WSDL could still define unexpected operations or endpoints.

16. **Monitor for threats** — The library logs warnings when suspicious XML patterns are detected. Monitor these logs in production for potential attack attempts.

17. **XPath injection protection** — The signature verifier validates element IDs against a strict allowlist pattern (XML NCName) before using them in XPath queries. This prevents attackers from injecting malicious XPath expressions through crafted Reference URIs in signed documents.

## Security Limitations

### Not Supported

The current implementation does not support:

- **XML Encryption** — Message content is not encrypted at the message level (use HTTPS for confidentiality)
- **SAML tokens** — SAML-based authentication is not supported
- **Kerberos tokens** — Kerberos authentication is not supported
- **Derived keys** — Key derivation for encryption is not supported
- **Signature confirmation** — Confirming which elements were signed in requests

### Known Limitations

- **UsernameToken uses SHA-1** — The WS-Security specification mandates SHA-1 for password digests. This cannot be changed without breaking compatibility with compliant servers.

- **No certificate chain validation** — The library verifies that signatures are valid for the provided certificate, but does not validate the certificate chain against a trust store or check certificate revocation (CRL/OCSP). Applications requiring this should implement additional validation.

- **No timestamp validation on responses** — While the library can verify response signatures, it does not automatically validate that response timestamps are within an acceptable time window. Applications can implement this check manually using the parsed timestamp values.

These features may be added in future releases.

## Troubleshooting

### Certificate/Key Mismatch

If you get an OpenSSL error about mismatched keys, ensure your private key corresponds to your certificate:

``` ruby
cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
key = OpenSSL::PKey::RSA.new(File.read('key.pem'))

# Verify they match
cert.check_private_key(key)  # Should return true
```

### Subject Key Identifier Not Found

If you get an error about missing SKI extension when using `:subject_key_identifier`:

``` ruby
# Check if certificate has SKI extension
cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
ski = cert.extensions.find { |e| e.oid == 'subjectKeyIdentifier' }
if ski
  puts "SKI: #{ski.value}"
else
  puts "Certificate does not have SKI extension, use :issuer_serial instead"
end
```

### Invalid Signature Errors

If the server rejects signatures:

1. Verify the server expects the digest algorithm you're using
2. Check that timestamps are within acceptable clock skew
3. Ensure the certificate is trusted by the server
4. Verify you're signing the elements the server expects
5. Try enabling `explicit_namespace_prefixes: true`

### Response Verification Failures

If response verification fails:

1. Check `response.signature_errors` for details
2. Ensure you have the correct server certificate
3. Verify the response actually contains a signature (`response.signature_present?`)
4. Check which elements are signed (`response.signed_elements`)

### Namespace Issues

Some servers are sensitive to namespace prefixes. If you encounter issues:

1. Try `explicit_namespace_prefixes: true`
2. Build the request and inspect the XML output with `operation.build`
3. Compare with working examples from the service documentation

## Reporting Security Issues

If you discover a security vulnerability in this library, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainers directly with details of the vulnerability
3. Include steps to reproduce the issue
4. Allow reasonable time for a fix before public disclosure

We take security seriously and will respond promptly to valid reports.