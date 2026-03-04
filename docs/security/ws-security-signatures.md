# WS-Security Signatures

Configure X.509 signing inside `ws_security`.

## Basic Signing

```ruby
certificate_pem = File.read('cert.pem')
private_key_pem = File.read('key.pem')

operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    signature(
      certificate: certificate_pem,
      private_key: private_key_pem
    )
    verify_response mode: :required
  end
end
```

Defaults:

- `digest_algorithm: :sha256`
- `sign_timestamp: true`
- `sign_addressing: false`
- `key_reference: :binary_security_token`

## Signature Options

```ruby
operation.prepare do
  tag('SubmitOrder') { tag('orderId', 123) }

  ws_security do
    timestamp expires_in: 300

    signature(
      certificate: certificate_pem,
      private_key: private_key_pem,
      digest_algorithm: :sha512,
      key_reference: :issuer_serial,
      sign_timestamp: true,
      sign_addressing: true,
      explicit_namespace_prefixes: true
    )
  end
end
```

Accepted `key_reference` values:

- `:binary_security_token`
- `:issuer_serial`
- `:subject_key_identifier`

SOAP Body is always signed when signatures are enabled.

## Encrypted Private Keys

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    signature(
      certificate: File.read('cert.pem'),
      private_key: File.read('encrypted-key.pem'),
      key_password: ENV.fetch('KEY_PASSWORD')
    )
  end
end
```

## Response Verification Policy

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    signature(certificate: cert_pem, private_key: key_pem)
    verify_response(
      mode: :required,
      trust_store: :system,
      check_validity: true,
      validate_timestamp: true,
      clock_skew: 300
    )
  end
end
```

`trust_store` supports:

- `:system`
- file path
- directory path
- array of certificates
- `OpenSSL::X509::Store`

Inbound signature verification requires `SignedInfo` to reference SOAP Body.

Certificate resolution order for inbound verification:

1. explicit `certificate:` option (if provided)
2. `ds:KeyInfo/wsse:SecurityTokenReference`:
   - `wsse:Reference` to embedded `wsse:BinarySecurityToken`
   - `ds:X509IssuerSerial` against certificates in `trust_store` arrays
   - `wsse:KeyIdentifier` with `#X509SubjectKeyIdentifier` against certificates in `trust_store` arrays

If no explicit certificate is provided and no usable `SecurityTokenReference` is present, verification fails.
Unreferenced `wsse:BinarySecurityToken` elements are not used for implicit certificate selection.

## Conflict Errors

If you manually inject conflicting WS-Security structures in the same request, `WSDL::RequestSecurityConflictError` is raised before sending.

## See also

- [WS-Security Overview](ws-security.md)
- [UsernameToken](ws-security-username-token.md)
- [WS-Security Troubleshooting](ws-security-troubleshooting.md)
- [Handling Responses](../core/handling-responses.md)
