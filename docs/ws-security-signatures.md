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
- `sign_body: true`
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
      sign_body: true,
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

## Conflict Errors

If you manually inject conflicting WS-Security structures in the same request, `WSDL::RequestSecurityConflictError` is raised before sending.
