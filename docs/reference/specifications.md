# Specifications and References

Implementation targets these standards and profiles:

## WSDL and SOAP

- WSDL 1.1
- SOAP 1.1 and SOAP 1.2
- XML Schema (XSD 1.0 constructs used in WSDL ecosystems)

> **Note:** WSDL 2.0 is not supported. See [Unsupported Features](unsupported-features.md) for details.

## WS-Security

- OASIS Web Services Security: SOAP Message Security 1.0/1.1
- UsernameToken Profile
- X.509 Token Profile
- XML Signature (as used by WS-Security)

## Security and Parsing Guidance

- OWASP recommendations for XML/XXE/SSRF hardening
- libxml2/Nokogiri secure parsing practices

## Notes

1. [`strictness:`](../core/configuration.md#strictness) governs import and request validation strictness.
2. Request generation is DSL -> Envelope -> XML with no Hash adapter layer.
3. See [Unsupported Features](unsupported-features.md) for features explicitly out of scope (WSDL 2.0, RPC/encoded, EncryptedKey, WS-SecurityPolicy, SwA/MTOM, XML Encryption).

## See also

- [Getting Started](../getting_started.md)
- [Configuration](../core/configuration.md)
- [WS-Security Overview](../security/ws-security.md)
- [Resolving Imports](../core/resolving-imports.md)
