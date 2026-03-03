# WS-Security UsernameToken

Configure UsernameToken inside `ws_security`.

## Plaintext Password

```ruby
operation.request do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password'
  end
end
```

## Password Digest

```ruby
operation.request do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true
  end
end
```

Digest mode uses the UsernameToken profile algorithm (SHA-1 as spec-mandated behavior).

## Fixed Creation Time

```ruby
operation.request do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true, created_at: Time.utc(2026, 1, 1, 0, 0, 0)
  end
end
```

## Combine with Timestamp

```ruby
operation.request do
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
operation.request do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    username_token 'username', 'password', digest: true
    verify_response mode: :required
  end
end
```
