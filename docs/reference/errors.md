# Error Hierarchy

All exceptions raised by this library inherit from `WSDL::Error` or `WSDL::FatalError`.

## Base Classes

```
StandardError
└── WSDL::Error                        # Recoverable domain errors
    └── WSDL::FatalError               # Non-recoverable / security violations
        └── WSDL::SecurityError        # Response verification failures
```

- **`WSDL::Error`** — base for all WSDL errors. Rescue this to catch everything.
- **`WSDL::FatalError`** — non-recoverable conditions (security violations, resource exhaustion, path restrictions). These should never be silently swallowed.
- **`WSDL::SecurityError`** — response security verification failures (signature, certificate, timestamp, algorithm). Rescue this to catch all verification errors at once.

## Full Hierarchy

```
WSDL::Error
├── WSDL::SchemaImportError
│   └── WSDL::SchemaImportParseError
├── WSDL::UnsupportedStyleError
├── WSDL::InvalidHTTPAdapterError
├── WSDL::UnresolvedReferenceError
├── WSDL::DuplicateDefinitionError
├── WSDL::RequestDefinitionError
├── WSDL::RequestValidationError
├── WSDL::RequestDslError
├── WSDL::SealedCollectionError
│
└── WSDL::FatalError
    ├── WSDL::SecurityError
    │   ├── WSDL::SignatureVerificationError
    │   ├── WSDL::CertificateValidationError
    │   ├── WSDL::TimestampValidationError
    │   └── WSDL::UnsupportedAlgorithmError
    ├── WSDL::XMLSecurityError
    ├── WSDL::RequestSecurityConflictError
    ├── WSDL::UnsupportedWSDLVersionError
    ├── WSDL::UnresolvableImportError
    ├── WSDL::UnsafeRedirectError
    ├── WSDL::PathRestrictionError
    └── WSDL::ResourceLimitError
```

## Error Categories

### Client / Request Errors

| Error | When |
|-------|------|
| `RequestDefinitionError` | `invoke` called without `prepare` on an operation that expects input |
| `RequestValidationError` | Request payload violates schema or structural constraints |
| `RequestDslError` | Invalid DSL usage (bad XML names, undeclared prefixes, reserved namespace override) |
| `RequestSecurityConflictError` | Manual request content conflicts with generated WS-Security (**fatal**) |

### Parsing / Import Errors

| Error | When |
|-------|------|
| `SchemaImportError` | Schema import fails (strict mode raises, relaxed mode logs and skips) |
| `SchemaImportParseError` | Imported schema cannot be parsed as XML |
| `UnresolvableImportError` | Relative import with no resolvable base location (**fatal**) |
| `UnsupportedStyleError` | Operation uses unsupported SOAP style (e.g. rpc/encoded) |
| `UnresolvedReferenceError` | Binding, portType, message, or schema reference cannot be resolved |
| `DuplicateDefinitionError` | Two imported documents define the same component key |

### Security Verification Errors (fatal)

All inherit from `WSDL::SecurityError < WSDL::FatalError`. Rescue `WSDL::SecurityError` to catch any of these.

| Error | When |
|-------|------|
| `SignatureVerificationError` | Response signature is missing, invalid, or does not cover SOAP Body |
| `CertificateValidationError` | Certificate expired, untrusted, or chain validation fails |
| `TimestampValidationError` | Response timestamp expired or clock skew exceeded |
| `UnsupportedAlgorithmError` | Unknown or unsupported algorithm URI in response signature |

### Other Fatal Errors

| Error | When |
|-------|------|
| `UnsupportedWSDLVersionError` | Document uses WSDL 2.0, which is not supported |
| `XMLSecurityError` | XML attack detected (entity amplification, excessive depth) |
| `UnsafeRedirectError` | HTTP redirect targets a private/reserved IP or DNS resolution fails |
| `PathRestrictionError` | File path violates sandbox restrictions |
| `ResourceLimitError` | Document size, schema count, or other limit exceeded |

### Infrastructure Errors

| Error | When |
|-------|------|
| `InvalidHTTPAdapterError` | Custom HTTP adapter missing required methods |
| `SealedCollectionError` | Internal: mutating a sealed parser collection |

## Rescue Patterns

```ruby
# Catch all WSDL errors
rescue WSDL::Error => e

# Catch only fatal errors
rescue WSDL::FatalError => e

# Catch all security verification errors
rescue WSDL::SecurityError => e

# Catch specific security errors
rescue WSDL::SignatureVerificationError => e
rescue WSDL::TimestampValidationError => e
```

## Source

All error definitions: `lib/wsdl/errors.rb`

## See also

- [Handling Responses](../core/handling-responses.md)
- [Configuration](../core/configuration.md)
- [WS-Security Troubleshooting](../security/ws-security-troubleshooting.md)
- [Resolving Imports](../core/resolving-imports.md)
