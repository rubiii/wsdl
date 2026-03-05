# Specifications and References

Implementation targets these standards and profiles:

## WSDL and SOAP

- WSDL 1.1
- SOAP 1.1 and SOAP 1.2
- XML Schema (XSD 1.0 constructs used in WSDL ecosystems)

## WS-Security

- OASIS Web Services Security: SOAP Message Security 1.0/1.1
- UsernameToken Profile
- X.509 Token Profile
- XML Signature (as used by WS-Security)

## Security and Parsing Guidance

- OWASP recommendations for XML/XXE/SSRF hardening
- libxml2/Nokogiri secure parsing practices

## Notes

1. RPC/encoded operations are intentionally unsupported.
2. [`strict_schema`](../core/configuration.md#strict-schema-mode) governs import strictness and request-validation strictness.
3. Request generation is DSL -> AST -> XML with no Hash adapter layer.

## See also

- [Getting Started](../getting_started.md)
- [Configuration](../core/configuration.md)
- [WS-Security Overview](../security/ws-security.md)
- [Resolving Imports](../core/resolving-imports.md)
