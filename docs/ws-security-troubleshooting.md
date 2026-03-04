# WS-Security Troubleshooting

## `RequestSecurityConflictError`

Cause: manual request XML conflicts with generated WS-Security structures.

Fix:

1. Remove manual `wsse:*`, `wsu:*`, or signature-specific elements/attributes from request DSL.
2. Keep security configuration only in `ws_security`.

## `SignatureVerificationError` on response

Cause: response signature missing/invalid under current verification policy.

Fix:

1. Confirm policy mode (`:required`, `:if_present`, `:disabled`).
2. Configure `trust_store` appropriately.
3. Confirm certificate chain and message integrity.

Example:

```ruby
operation.prepare do
  tag('GetOrder') { tag('orderId', 123) }

  ws_security do
    verify_response mode: :if_present, trust_store: :system
  end
end
```

## `TimestampValidationError`

Cause: response timestamp outside allowed window.

Fix:

1. Increase `clock_skew` if clocks differ.
2. Ensure system clocks are synchronized.
3. Disable timestamp validation only in controlled environments.

```ruby
ws_security do
  verify_response clock_skew: 600
end
```

## `UnsupportedAlgorithmError`

Cause: peer uses an unsupported signature or digest algorithm URI.

Fix:

1. Align server/client algorithm suite.
2. Confirm SHA-256 or compatible policy where possible.

## UsernameToken authentication fails

Cause: server expects digest or specific timestamp behavior.

Fix:

1. Switch to `digest: true`.
2. Add `timestamp` if required by server policy.
3. Inspect outbound SOAP XML (`operation.to_xml`) for final header content.

## Debugging Tips

- Log outbound XML from `operation.to_xml` in non-production.
- Inspect `response.raw` for returned security headers.
- Check `response.security.errors` and `response.security.signed_elements`.
- Start with `verify_response mode: :if_present` while integrating, then harden to `:required`.
