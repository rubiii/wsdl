---
paths:
  - "lib/**/*.rb"
---

# Library Code Conventions

## Immutability

Data structures representing parsed WSDL state must be frozen. `Definition` deep-freezes its entire IR hash on construction. Config objects freeze after setup. Return frozen arrays/hashes from public methods. Never mutate cached data.

## Error Hierarchy

- `WSDL::Error` — recoverable (controlled by strictness settings)
- `WSDL::FatalError` — non-recoverable (security, safety, structural)
- `WSDL::SecurityError < FatalError` — response verification failures

Errors carry custom keyword attributes for machine-readable context. Error messages must include recovery guidance:

```ruby
raise ResourceLimitError.new(
  "Response size #{actual} exceeds limit of #{max}" \
  "\nTo increase, use: limits: { max_response_size: #{actual} }",
  limit_name: :max_response_size, limit_value: max, actual_value: actual
)
```

## YARD Documentation

- All public methods: summary line, `@param`, `@return`, `@raise`, `@example`
- Internal methods: `@api private` — still fully documented with `@param`/`@return`
- Multiple signatures: use `@overload` tags with position-based `*args` dispatch
- Constants: `@return [Type]` with a descriptive comment above
- Internal links: `@see file:docs/core/configuration.md`
- External specs: `@see https://docs.oasis-open.org/wss/v1.1/...`

## Security Code

- All protocol URIs live in centralized constant modules (`WSDL::NS`, `WSDL::Security::Constants`) — no magic strings
- Link to OASIS/W3C specifications in `@see` tags
- Per-request artifacts (nonce, timestamps, IDs) must never be reused across requests
- Config objects are frozen after construction

## Code Patterns

- Guard clauses with early returns to reduce nesting
- `attr_reader` for simple value access; methods for computed or delegated values
- Three-tier config: global defaults -> client instance -> per-operation overrides (use `defined?(@ivar)` to distinguish unset from nil)
- Overloaded methods dispatch on `args.size` with clear `ArgumentError` messages listing valid signatures
