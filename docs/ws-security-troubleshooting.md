# Troubleshooting & Limitations

This guide covers common issues, limitations, and how to report security problems.

> **Quick Links:** [Main WS-Security Guide](ws-security.md) | [UsernameToken](ws-security-username-token.md) | [X.509 Signatures](ws-security-signatures.md) | [XML Safety](ws-security-xml-safety.md)

## Common Issues

### Certificate/Key Mismatch

If you get an OpenSSL error about mismatched keys, ensure your private key corresponds to your certificate:

```ruby
cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
key = OpenSSL::PKey::RSA.new(File.read('key.pem'))

# Verify they match
cert.check_private_key(key)  # Should return true
```

### Subject Key Identifier Not Found

If you get an error about missing SKI extension when using `:subject_key_identifier`:

```ruby
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

### Clock Skew Problems

If you're getting timestamp-related errors:

1. Ensure your system clock is synchronized (use NTP)
2. Try increasing the timestamp expiration: `timestamp(expires_in: 600)`
3. Check if the server has a different clock skew tolerance

### SSL Certificate Verification

If you're having SSL issues connecting to the WSDL endpoint:

```ruby
# DANGEROUS - Never do this in production!
# client.http.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

# Instead, configure proper CA certificates:
client.http.ssl_config.add_trust_ca('/path/to/ca-bundle.crt')
```

---

## Limitations

### Not Supported

The current implementation does not support:

| Feature | Description | Workaround |
|---------|-------------|------------|
| **XML Encryption** | Message-level content encryption | Use HTTPS for confidentiality |
| **SAML tokens** | SAML-based authentication | Use UsernameToken or X.509 |
| **Kerberos tokens** | Kerberos authentication | Use UsernameToken or X.509 |
| **Derived keys** | Key derivation for encryption | Not available |
| **Signature confirmation** | Confirming which elements were signed | Check `signed_elements` manually |

### Known Limitations

#### UsernameToken Uses SHA-1

The WS-Security specification mandates SHA-1 for password digests. This cannot be changed without breaking compatibility with compliant servers.

**Mitigation:** Use strong passwords (the real security factor) or switch to X.509 signatures for configurable algorithms.

#### No Certificate Chain Validation

The library verifies that signatures are valid for the provided certificate, but does not:

- Validate the certificate chain against a trust store
- Check certificate revocation (CRL/OCSP)

**Mitigation:** Applications requiring this should implement additional validation:

```ruby
# Example: Manual certificate validation
def validate_certificate(cert)
  store = OpenSSL::X509::Store.new
  store.add_file('/path/to/ca-bundle.crt')
  store.verify(cert)
end
```

#### No Timestamp Validation on Responses

While the library can verify response signatures, it does not automatically validate that response timestamps are within an acceptable time window.

**Mitigation:** Implement manual timestamp checking:

```ruby
# Example: Manual timestamp validation
def valid_timestamp?(response, max_age: 300)
  # Parse timestamp from response and check age
  # Implementation depends on your requirements
end
```

---

## Debugging Tips

### Preview the Request

Use `build` to see the complete SOAP envelope with security headers:

```ruby
operation.security.username_token('user', 'secret', digest: true)
operation.body = { GetOrder: { orderId: 123 } }

puts operation.build
```

### Check Configuration State

Inspect the current security configuration:

```ruby
operation.security.configured?                   # Any security configured?
operation.security.username_token?               # UsernameToken configured?
operation.security.timestamp?                    # Timestamp configured?
operation.security.signature?                    # X.509 signing configured?
operation.security.sign_addressing?              # WS-Addressing signing enabled?
operation.security.explicit_namespace_prefixes?  # Explicit prefixes enabled?
operation.security.verify_response?              # Response verification enabled?
operation.security.key_reference                 # => :binary_security_token
```

### Clear and Retry

To remove all security configuration and start fresh:

```ruby
operation.security.clear
```

### Enable HTTP Debugging

To see the raw HTTP request/response:

```ruby
client.http.debug_dev = $stderr
```

---

## Reporting Security Issues

If you discover a security vulnerability in this library:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainers directly with details of the vulnerability
3. Include steps to reproduce the issue
4. Allow reasonable time for a fix before public disclosure

We take security seriously and will respond promptly to valid reports.

---

## Related Documentation

- [Main WS-Security Guide](ws-security.md) — Overview and choosing authentication methods
- [UsernameToken Authentication](ws-security-username-token.md) — Password-based authentication
- [X.509 Certificate Signatures](ws-security-signatures.md) — Digital signatures
- [XML Parsing Security](ws-security-xml-safety.md) — Protection against XML attacks