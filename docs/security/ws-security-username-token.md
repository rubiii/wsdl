# WS-Security UsernameToken

Configure UsernameToken inside `ws_security`.

## Plaintext Password

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password'
  end
end
```

## See also

- [WS-Security Overview](ws-security.md)
- [WS-Security Signatures](ws-security-signatures.md)
- [WS-Security Troubleshooting](ws-security-troubleshooting.md)
- [Handling Responses](../core/handling-responses.md)

## Password Digest

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true
  end
end
```

Digest mode uses the UsernameToken profile algorithm (SHA-1 as spec-mandated behavior).

## Fixed Creation Time

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true, created_at: Time.utc(2026, 1, 1, 0, 0, 0)
  end
end
```

## Combine with Timestamp

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    timestamp expires_in: 300
    username_token 'username', 'password', digest: true
  end
end
```

## Response Verification

UsernameToken itself does not verify response signatures. Add explicit policy:

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true
    verify_response mode: :required
  end
end
```
