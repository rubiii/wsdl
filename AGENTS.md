# AGENTS.md

WSDL toolkit for Ruby. Turn WSDL 1.1 documents into inspectable services and callable operations.

## Priorities

- **Developer happiness** — clear errors, good defaults, minimal configuration
- **Code quality** — 100% YARD docs, 95%+ coverage, clean RuboCop, no shortcuts
- **Security** — maintain and extend defenses (XXE, SSRF, XML Signature); never regress
- **Specification compliance** — code must conform to W3C/OASIS specs; local copies in `docs/reference/specs/`, overview in `docs/reference/specifications.md`
- **Automation** — build tools that verify correctness, enforce quality, and reduce manual work
- **Performance** — the parser is designed for speed; measure before and after changes

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

## Workflow

- **CI must pass before a task is complete.** Run `bundle exec rake ci` (lint + YARD audit + tests). RuboCop runs automatically on every file edit via a hook — let it autofix.
- **When implementing protocol behavior**, consult the local spec docs in `docs/reference/specs/` and reference the relevant section.

## Testing

Every public method must be tested, 100% coverage is a must. See [Testing docs](docs/testing.md) for test structure, fixtures, helpers, and coverage requirements.
