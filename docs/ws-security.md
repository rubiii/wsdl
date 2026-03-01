# WS-Security

This guide covers the WS-Security (Web Services Security) features available in the WSDL library.

## Overview

WS-Security provides a standard way to secure SOAP messages through:

- **Authentication** — UsernameToken with plain text or digest passwords
- **Message Integrity** — Timestamps and X.509 digital signatures
- **Replay Protection** — Nonces and expiration times
- **Response Verification** — Validate signed responses from the server

The library implements the following OASIS specifications:

- [SOAP Message Security 1.1](https://docs.oasis-open.org/wss/v1.1/)
- [UsernameToken Profile 1.1](https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf)
- [X.509 Token Profile 1.1](https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf)

## Detailed Guides

| Guide | Description |
|-------|-------------|
| [UsernameToken Authentication](ws-security-username-token.md) | Password-based authentication (plain text and digest modes) |
| [X.509 Certificate Signatures](ws-security-signatures.md) | Digital signatures, response verification, key reference methods |
| [XML Parsing Security](ws-security-xml-safety.md) | Built-in protections against XXE, SSRF, and XML attacks |
| [Troubleshooting](ws-security-troubleshooting.md) | Common issues, limitations, and debugging tips |

## Choosing an Authentication Method

| Method | Password Transmitted? | Replay Protection | Algorithm | Best For |
|--------|----------------------|-------------------|-----------|----------|
| UsernameToken (plain text) | Yes (use HTTPS!) | No | None | Development, simple auth |
| UsernameToken (digest) | No | Yes | SHA-1 (spec-mandated) | Production password auth |
| X.509 Signature | N/A | Yes | SHA-256/512 (configurable) | High-security, compliance |

### Decision Guide

**Use [UsernameToken with plain text](ws-security-username-token.md)** when:
- You're in a development or testing environment
- The service requires plain text passwords
- You have HTTPS configured (mandatory)

**Use [UsernameToken with digest](ws-security-username-token.md#digest-password)** when:
- You need password-based authentication in production
- You want the password to never leave the client
- You need replay attack protection

**Use [X.509 Certificate Signatures](ws-security-signatures.md)** when:
- You have compliance requirements (PCI-DSS, HIPAA, etc.)
- You need non-repudiation (proof of sender identity)
- You require SHA-256 or SHA-512 algorithms
- You're in a high-security environment

> **Recommendation:** For most production scenarios, use **UsernameToken with digest mode** over HTTPS. For high-security requirements, use **X.509 Certificate Signatures**.

## Quick Start

### Basic Usage

```ruby
client = WSDL::Client.new('http://example.com/service?wsdl')
operation = client.operation('Service', 'Port', 'Operation')

# Configure security
operation.security.username_token('user', 'secret', digest: true)

# Set request body and call
operation.body = { GetOrder: { orderId: 123 } }
response = operation.call
```

### Fluent Configuration

```ruby
operation.security
  .timestamp(expires_in: 300)
  .username_token('user', 'secret', digest: true)
```

### Full Example with X.509 Signing

```ruby
require 'wsdl'

client = WSDL::Client.new('https://secure-service.example.com/orders?wsdl')
operation = client.operation('OrderService', 'OrderServiceSoap', 'GetOrder')

# Configure security
operation.security
  .timestamp(expires_in: 300)
  .username_token('api_user', 'api_secret', digest: true)
  .signature(
    certificate: File.read('client_cert.pem'),
    private_key: File.read('client_key.pem'),
    digest_algorithm: :sha256
  )

# Enable response verification
operation.security.verify_response = true

# Make the call
operation.body = { GetOrder: { orderId: 12345 } }
response = operation.call

# Process verified response
if response.signature_valid?
  puts response.body
else
  raise "Verification failed: #{response.signature_errors.join(', ')}"
end
```

## Security Best Practices

### Transport Security

1. **Always use HTTPS** — WS-Security provides message-level security, but HTTPS provides confidentiality and network-level protection.

2. **Verify SSL certificates** — Never disable SSL verification in production.

### Authentication

3. **Prefer X.509 for high-security scenarios** — Provides strongest authentication with configurable algorithms.

4. **Use digest mode for UsernameToken** — Password is never transmitted, provides replay protection.

5. **Use strong passwords** — Password strength is the primary security factor for UsernameToken.

6. **Protect credentials** — Never hardcode passwords or private keys. Use environment variables or secrets managers.

### Cryptographic Algorithms

7. **Use SHA-256 or stronger for signatures** — SHA-1 is deprecated; use SHA-256 (default) or SHA-512.

8. **Understand UsernameToken SHA-1 limitation** — The WS-Security spec mandates SHA-1 for password digests. See [Security Considerations](ws-security-username-token.md#security-considerations) for details.

### Key Management

9. **Protect private keys** — Use encrypted keys and appropriate file permissions (`chmod 600`).

10. **Use RSA 2048-bit minimum** — 4096-bit recommended for long-term security.

11. **Rotate certificates regularly** — Have a process for rotation before expiration.

### Message Security

12. **Use appropriate timestamp expiration** — Default 5 minutes balances security and clock skew tolerance.

13. **Verify response signatures** — Enable `verify_response` for high-security scenarios.

14. **Sign WS-Addressing headers** — Prevents routing attacks if using WS-Addressing.

## Checking Configuration

```ruby
operation.security.configured?       # Any security configured?
operation.security.username_token?   # UsernameToken configured?
operation.security.timestamp?        # Timestamp configured?
operation.security.signature?        # X.509 signing configured?
operation.security.verify_response?  # Response verification enabled?
```

## Previewing the Request

```ruby
puts operation.build  # See the complete SOAP envelope
```

## Clearing Configuration

```ruby
operation.security.clear  # Remove all security configuration
```

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do not** open a public GitHub issue
2. Email the maintainers directly with details
3. Include steps to reproduce
4. Allow reasonable time for a fix before disclosure