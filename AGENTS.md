# AGENTS.md

WSDL toolkit for Ruby. Turn WSDL 1.1 documents into inspectable services and callable operations.

## Project Status

This library is being revived. It was previously published as `Sekken` but is now renamed to `WSDL`. The gem is currently unpublished, so we don't need to care about backward compatibility at all. Big changes are welcome!

## Getting Started

```sh
bundle install          # Install dependencies
bundle exec rspec       # Run tests
bundle exec rubocop     # Run linter
bundle exec rake ci     # Run all checks (CI task)
bundle exec yard        # Generate YARD documentation
```

## Key Concepts

- **Client** — Main entry point (`lib/wsdl/client.rb`)
- **Operation** — Callable SOAP operation with body, headers, and security
- **Parser** — Parses WSDL and XSD documents
- **Request DSL + Serializer** — `operation.prepare { ... }` builds AST and `WSDL::Request::Serializer` / `Operation#to_xml` produce SOAP envelopes
- **Response** — Wraps SOAP responses with parsing and verification
- **Security** — WS-Security implementation (see `docs/security/ws-security.md`)

## Workflow Rules

1. **Always make a plan first.** Propose a plan and wait for explicit confirmation before making changes.

2. **Run quality checks after every code change.** Run `bundle exec rake ci` to ensure both RuboCop and RSpec pass. Never consider a task complete until CI is green. Let RuboCop autofix problems.

3. **Follow the official specifications.** Code must conform to the W3C and OASIS specifications in `docs/reference/specifications.md`.

4. **Update documentation after every change.** Check if YARD docs, `docs/` folder, `AGENTS.md`, or `README.md` need updates. Run `bundle exec yard` to verify.

## Code Style

- Ruby 3.2+ with modern idioms (shorthand hash syntax, Data classes)
- `# frozen_string_literal: true` at the top of every file
- Single quotes for strings, 120 character max line length
- Semantic blocks: `do...end` for side effects, `{...}` for return values
- Follow `.rubocop.yml` — prefer inline ignores over global rule changes

## Testing

- Every public method must be tested, 100% coverage is a must
- Use existing fixtures in `spec/fixtures/` (45+ real-world WSDLs)
- Unit tests in `spec/wsdl/` mirror `lib/wsdl/` structure
- Integration tests in `spec/integration/`

## Documentation

- Complete YARD docs for all public methods (enforced by `rubocop-yard`)
- Use proper YARD type syntax: `Hash{String => String}` not `Hash<String, String>`
- Use the latest YARD version and features where possible; review updates in `https://rubydoc.info/gems/yard/file/docs/WhatsNew.md`
- Detailed docs live in `docs/` folder; keep README brief

## Error Handling

Exception definitions and the current hierarchy are in `lib/wsdl/errors.rb` (source of truth).

General guidance:

- Use `WSDL::Error` for recoverable domain errors that callers may reasonably handle and continue from.
- Use `WSDL::FatalError` for non-recoverable conditions, especially security violations or hard safety constraints that must not be ignored.
- New custom exceptions should inherit from one of these two base classes and be defined in `lib/wsdl/errors.rb`.

## Naming Conventions

- Class/module names should match their role (`*Parser`, `*Validator`, `*Resolver`, `*Contract`, `*Policy`, `*Context`, `*Builder` when actually building structures).
- Keep namespaces and file paths aligned (e.g., `WSDL::Parser::Result` in `lib/wsdl/parser/result.rb`).
- Predicate methods: `?` suffix and boolean return values (e.g., `configured?`).
- Bang methods: `!` suffix for strict/raising or state-changing variants (e.g., `validate!`, `verify!`, `seal!`).
- Exception classes: `*Error` suffix and inheritance from `WSDL::Error` or `WSDL::FatalError`.
- Avoid generic names like `Helper`, `Manager`, or `Utils` unless the scope is very narrow and explicit.

## Security

WS-Security docs: `docs/security/ws-security*.md`

Key points:
- Never log or expose private keys, passwords, or tokens
- Use constants from `WSDL::Security::Constants` — never hardcode namespace URIs
- SHA-256 is the default for X.509 signatures
- UsernameToken digest uses SHA-1 (spec-mandated, not a bug)

## Common Pitfalls

- **XML Namespaces** — Use constants (`WSDL::NS::SOAP_1_1`, `WSDL::Security::Constants::NS::Security::WSSE`), never hardcode URIs
- **WSDL Variability** — Test against multiple fixtures; don't assume consistent structure
- **SOAP Versions** — 1.1 and 1.2 use different namespaces; the WSDL determines which to use
- **Import Resolution** — Relative imports require a base location; see `UnresolvableImportError`

## Quick Links

| Resource | Path |
|----------|------|
| Main entry point | `lib/wsdl/client.rb` |
| Error definitions | `lib/wsdl/errors.rb` |
| Namespace constants | `lib/wsdl/ns.rb` |
| Security constants | `lib/wsdl/security/constants.rb` |
| WS-Security docs | `docs/security/ws-security.md` |
| Specifications | `docs/reference/specifications.md` |
