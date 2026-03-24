# AGENTS.md

WSDL toolkit for Ruby. Turn WSDL 1.1 documents into inspectable services and callable operations.


## Getting Started

@docs/development.md

## Key Concepts

- **Definition** — Frozen IR of a parsed WSDL service (`lib/wsdl/definition.rb`). Created by `WSDL.parse`, restored by `WSDL.load`. Provides discovery, introspection, provenance, and serialization. Everything downstream operates on the Definition.
- **Client** — Wraps a Definition with an HTTP adapter for calling operations (`lib/wsdl/client.rb`)
- **Operation** — Callable SOAP operation with body, headers, and security
- **Parser** — Parses WSDL and XSD documents into intermediate structures consumed by the Definition Builder
- **Request DSL + Serializer** — `operation.prepare { ... }` builds a `Request::Envelope` and `WSDL::Request::Serializer` / `Operation#to_xml` produce SOAP XML
- **Response** — Wraps SOAP responses with parsing and verification
- **Security** — WS-Security implementation (see `docs/security/ws-security.md`)

## Workflow Rules

1. **Always make a plan first.** Propose a plan and wait for explicit confirmation before making changes.

2. **Run quality checks after every code change.** Run `bundle exec rake ci` to ensure both RuboCop and RSpec pass. Never consider a task complete until CI is green. Let RuboCop autofix problems.

3. **Follow the official specifications.** Code must conform to the W3C and OASIS specifications in `docs/reference/specifications.md`.

4. **Update documentation after every change.** Check if YARD docs, `docs/` folder, `AGENTS.md`, or `README.md` need updates. Run `bundle exec yard` to verify.

5. **Capture full test output.** Never pipe test or CI commands through `grep`, `tail`, or `head`. Property-based tests include randomized inputs in failure output — filtering loses them permanently.

## Testing

- Every public method must be tested, 100% coverage is a must
- Use existing fixtures in `spec/fixtures/` (real-world WSDLs)
- Unit tests in `spec/wsdl/` mirror `lib/wsdl/` structure
- Acceptance tests in `spec/acceptance/` (real WSDLs, no network)
- Integration tests in `spec/integration/` (live mock services, auto-tagged `:test_service`)
- Conformance tests in `spec/conformance/` (W3C/OASIS spec assertions)
- Property-based tests in `spec/property/` use Rantly (`PROPERTY_TRIALS` env var, default 100)
- See [Testing docs](docs/testing.md) for full details

## Quick Links

| Resource | Path |
|----------|------|
| Main entry point | `lib/wsdl/client.rb` |
| Error definitions | `lib/wsdl/errors.rb` |
| Namespace constants | `lib/wsdl/ns.rb` |
| Security constants | `lib/wsdl/security/constants.rb` |
| Development guidelines | `docs/development.md` |
| WS-Security docs | `docs/security/ws-security.md` |
| Specifications | `docs/reference/specifications.md` |
| Benchmarks | `docs/reference/benchmarks.md` |
| Testing docs | `docs/testing.md` |
