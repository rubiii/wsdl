# Error Hierarchy

All exceptions raised by this library inherit from `WSDL::Error` or `WSDL::FatalError`.

## Base Classes

```
StandardError
└── WSDL::Error                        # Recoverable domain errors
    └── WSDL::FatalError               # Non-recoverable / security violations
```

- **`WSDL::Error`** — base for all WSDL errors. Rescue this to catch everything.
- **`WSDL::FatalError`** — non-recoverable conditions (security violations, resource exhaustion, path restrictions). These should never be silently swallowed.

## Full Hierarchy

```
WSDL::Error
├── WSDL::SchemaImportError
│   └── WSDL::SchemaImportParseError
├── WSDL::UnsupportedStyleError
├── WSDL::InvalidHTTPAdapterError
├── WSDL::SignatureVerificationError
├── WSDL::CertificateValidationError
├── WSDL::TimestampValidationError
├── WSDL::UnsupportedAlgorithmError
├── WSDL::UnresolvedReferenceError
├── WSDL::DuplicateDefinitionError
├── WSDL::RequestDefinitionError
├── WSDL::RequestValidationError
├── WSDL::RequestDslError
├── WSDL::SealedCollectionError
│
└── WSDL::FatalError
    ├── WSDL::UnresolvableImportError
    ├── WSDL::PathRestrictionError
    ├── WSDL::XMLSecurityError
    ├── WSDL::RequestSecurityConflictError
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

### Security Errors

| Error | When |
|-------|------|
| `SignatureVerificationError` | Response signature is missing, invalid, or does not cover SOAP Body |
| `CertificateValidationError` | Certificate expired, untrusted, or chain validation fails |
| `TimestampValidationError` | Response timestamp expired or clock skew exceeded |
| `UnsupportedAlgorithmError` | Unknown or unsupported algorithm URI in response signature |
| `XMLSecurityError` | XML attack detected (entity amplification, excessive depth) (**fatal**) |

### Infrastructure Errors

| Error | When |
|-------|------|
| `InvalidHTTPAdapterError` | Custom HTTP adapter missing required methods |
| `PathRestrictionError` | File path violates sandbox restrictions (**fatal**) |
| `ResourceLimitError` | Document size, schema count, or other limit exceeded (**fatal**) |
| `SealedCollectionError` | Internal: mutating a sealed parser collection |

## Rescue Patterns

```ruby
# Catch all WSDL errors
rescue WSDL::Error => e

# Catch only fatal errors
rescue WSDL::FatalError => e

# Catch security errors during verification
rescue WSDL::SignatureVerificationError,
       WSDL::CertificateValidationError,
       WSDL::TimestampValidationError => e
```

## Source

All error definitions: `lib/wsdl/errors.rb`

## See also

- [Handling Responses](../core/handling-responses.md)
- [Configuration](../core/configuration.md)
- [WS-Security Troubleshooting](../security/ws-security-troubleshooting.md)
- [Resolving Imports](../core/resolving-imports.md)
