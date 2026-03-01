# UsernameToken Authentication

This guide covers password-based authentication using WS-Security UsernameToken.

> **Quick Links:** [Main WS-Security Guide](ws-security.md) | [X.509 Signatures](ws-security-signatures.md) | [Troubleshooting](ws-security-troubleshooting.md)

## Overview

UsernameToken provides username/password authentication for SOAP services. It supports two modes:

| Mode | Password Transmitted? | Replay Protection | When to Use |
|------|----------------------|-------------------|-------------|
| Plain text | Yes | No | Development, simple auth over HTTPS |
| Digest | No (only hash) | Yes (nonce + timestamp) | Production environments |

## Plain Text Password

The simplest form sends the password in plain text. **Only use this over HTTPS:**

```ruby
operation.security.username_token('username', 'password')
```

This produces XML like:

```xml
<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
  <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
    <wsse:Username>username</wsse:Username>
    <wsse:Password Type="...#PasswordText">password</wsse:Password>
  </wsse:UsernameToken>
</wsse:Security>
```

## Digest Password

Digest mode hashes the password with a nonce and timestamp. The password is **never transmitted**:

```ruby
operation.security.username_token('username', 'password', digest: true)
```

The digest is computed as: `Base64(SHA-1(nonce + created + password))`

This produces XML like:

```xml
<wsse:Security xmlns:wsse="...">
  <wsse:UsernameToken wsu:Id="UsernameToken-abc123">
    <wsse:Username>username</wsse:Username>
    <wsse:Password Type="...#PasswordDigest">hashed_value</wsse:Password>
    <wsse:Nonce EncodingType="...#Base64Binary">random_nonce</wsse:Nonce>
    <wsu:Created>2025-01-15T12:00:00Z</wsu:Created>
  </wsse:UsernameToken>
</wsse:Security>
```

## Custom Timestamp

You can specify a custom creation timestamp:

```ruby
operation.security.username_token(
  'username',
  'password',
  digest: true,
  created_at: Time.utc(2025, 1, 15, 12, 0, 0)
)
```

## Security Considerations

### Why Digest Mode is Recommended

Digest mode provides significant security advantages over plain text:

| Aspect | Plain Text | Digest |
|--------|------------|--------|
| Password in message | Yes | No (only hash) |
| Replay protection | None | Nonce + timestamp |
| Requires HTTPS | Mandatory | Recommended |
| Server learns password | Yes | No |

With digest mode, even if an attacker intercepts the message, they cannot:

- **Recover the original password** — the hash is one-way
- **Replay the message** — the nonce is unique, the timestamp expires
- **Use the digest elsewhere** — it's bound to the specific nonce and timestamp

### Understanding the SHA-1 Limitation

The digest formula uses SHA-1 because the WS-Security UsernameToken Profile 1.1 specification **mandates** it. This is a protocol constraint — servers expecting WS-Security compliance will reject non-SHA-1 digests.

**Why SHA-1's weaknesses don't directly impact password security:**

1. **Collision attacks** (SHA-1's known weakness) find two different inputs that produce the same hash. This is useful for forging certificates, not cracking passwords.

2. **Preimage attacks** (recovering input from hash) remain computationally infeasible for SHA-1. An attacker cannot reverse the hash to find your password.

3. **The nonce changes every request**, so attackers cannot precompute rainbow tables or reuse captured digests.

4. **The real risk is weak passwords.** A strong password is far more important than the hash algorithm. Use passwords with high entropy.

### When to Use X.509 Signatures Instead

Consider upgrading to [X.509 certificate signatures](ws-security-signatures.md) when:

- You have **compliance requirements** (PCI-DSS, HIPAA, SOX)
- You need **non-repudiation** (cryptographic proof of sender identity)
- You require **SHA-256 or SHA-512** algorithms
- You're building **high-security applications** (financial, healthcare, government)

```ruby
# X.509 signatures support configurable algorithms
operation.security.signature(
  certificate: cert,
  private_key: key,
  digest_algorithm: :sha256  # or :sha512
)
```

## Combining with Other Security Features

UsernameToken can be combined with timestamps and signatures:

```ruby
operation.security
  .timestamp(expires_in: 300)
  .username_token('user', 'secret', digest: true)
  .signature(
    certificate: cert,
    private_key: key,
    digest_algorithm: :sha256
  )
```

## Best Practices

1. **Always use HTTPS** — regardless of password mode
2. **Prefer digest mode** over plain text for production
3. **Use strong passwords** — this is the primary security factor
4. **Never hardcode credentials** — use environment variables or secrets managers
5. **Consider X.509 signatures** for high-security requirements

## Related Documentation

- [Main WS-Security Guide](ws-security.md) — Overview and choosing authentication methods
- [X.509 Certificate Signatures](ws-security-signatures.md) — Stronger authentication option
- [Troubleshooting](ws-security-troubleshooting.md) — Common issues and solutions