# XML Safety

This library applies XML safety controls during parsing and request generation.

## Parser Defenses

By default:

- DOCTYPE declarations are rejected (`reject_doctype: true`).
- XML parsing uses secure settings via Nokogiri/libxml2 safeguards.
- Local import resolution is sandboxed.
- Resource limits protect against oversized or deeply nested schema graphs.

## Import Path Safety

Relative file imports are constrained by sandbox paths.

- File-based WSDL defaults to sandbox = WSDL parent directory.
- URL-based WSDL disables local file access by default.

Violations raise `WSDL::PathRestrictionError`.

## Request DSL Safety

Request generation enforces:

- XML NCName/QName validation for element and attribute names.
- Namespace prefix declaration checks.
- Reserved prefix protection for SOAP and WS-Security prefixes.
- Duplicate attribute rejection.
- Request AST resource limits (`max_request_elements`, `max_request_depth`, `max_request_attributes`).

## Text Escaping

Text and attribute values are XML-escaped automatically. Use `cdata(...)` when verbatim XML text is required.

## Security Errors

Relevant error classes:

- `WSDL::XMLSecurityError`
- `WSDL::PathRestrictionError`
- `WSDL::ResourceLimitError`
- `WSDL::RequestDslError`
- `WSDL::RequestSecurityConflictError`

## See also

- [WS-Security Overview](ws-security.md)
- [Resolving Imports](../core/resolving-imports.md)
- [Configuration](../core/configuration.md)
