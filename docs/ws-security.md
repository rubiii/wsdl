# WS-Security

WS-Security is configured inside `operation.request` using `ws_security`.

```ruby
operation.request do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    timestamp expires_in: 300
    username_token 'api-user', 'secret', digest: true
    verify_response mode: :required
  end
end
```

## Outbound Features

Inside `ws_security` you can configure:

- `username_token(username, password, digest: false, created_at: nil)`
- `timestamp(created_at: nil, expires_in: 300, expires_at: nil)`
- `signature(certificate:, private_key:, **options)`

## Inbound Verification

Configure response verification policy with:

- `verify_response(mode: :required | :if_present | :disabled, trust_store:, check_validity:, validate_timestamp:, clock_skew:)`

Default mode is `:required`.

## SOAP Version Behavior

Security header `mustUnderstand` is emitted per SOAP version:

- SOAP 1.1: `"1"`
- SOAP 1.2: `"true"`

## Conflict Detection

When outbound security is configured, manually defining conflicting WS-Security structures in the request DSL raises `WSDL::RequestSecurityConflictError`.

Detection is namespace-aware (expanded names), not prefix-based.

## Related Guides

- [UsernameToken](ws-security-username-token.md)
- [Signatures](ws-security-signatures.md)
- [XML Safety](ws-security-xml-safety.md)
- [Troubleshooting](ws-security-troubleshooting.md)
