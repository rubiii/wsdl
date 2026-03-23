# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Extract XML attributes from response elements into the parsed hash with `_`-prefixed keys (e.g., `transactionKey="TXN-123"` → `_transactionKey: "TXN-123"`). Attributes are type-coerced when schema metadata is available.
- One-way operations (no `<output>` message) are now supported. Response contract returns empty elements and `output_style` returns `nil`.
- Operation overloading support per WSDL 1.1 §2.4.5. Same-named operations with different input/output messages are stored correctly and disambiguated via `client.operation(:Svc, :Port, :Op, input_name: :InputName)`. WS-I Basic Profile R2304 validation in strict mode raises `OperationOverloadError`.
- `strictness:` replaces the `strict_schema` boolean with granular control over 4 validation concerns: `schema_imports`, `schema_references`, `operation_overloading`, `request_validation`. Accepts a hash (`strictness: { schema_imports: false }`), boolean (`strictness: false`), or object.
- All `ResourceLimitError` and strictness error messages now include copy-pasteable fix examples (e.g., `limits: { max_schemas: 51 }`, `strictness: { schema_imports: false }`).
- `limits:` now accepts a hash shorthand (`limits: { max_schemas: 200 }`) in addition to a `Limits` object.
- All 46 XSD built-in types are now explicitly handled by `TypeCoercer`. List types (`IDREFS`, `ENTITIES`, `NMTOKENS`) are now get coerced into arrays.
- `xs:group` (model group) references are now resolved and their elements expanded, mirroring the existing `xs:attributeGroup` support.
- `xs:list` simpleType derivation is now supported for both elements and attributes. List values are parsed by splitting on whitespace, with per-item type coercion based on the `itemType`. Built by joining array values with spaces.
- `xs:union` simpleType derivation is now supported for both elements and attributes. The first `memberType` is used as the base type for coercion.
- `Element#kind` returns `:simple`, `:complex`, or `:recursive` for programmatic dispatch. Included in both `paths` and `tree` contract output.
- `Attribute#to_h` provides a consistent hash representation. Contract `paths` and `tree` now return identical attribute metadata including `name`, `type`, `required`, and `list`.

### Deprecated

- `strict_schema:` keyword on `Client.new` and `Config.new`. Use `strictness:` instead.

### Fixed

- RPC/literal responses now receive schema-aware type coercion. Previously, the RPC wrapper element prevented the parser from matching schema parts, so all values were returned as strings instead of typed Ruby objects (Integer, Date, BigDecimal, etc.).
- Documents without a root XML element (empty files, binary content, truncated XML, non-XML responses from imports) now raise `WSDL::Error` instead of `NoMethodError`.
- Binding operations missing a required `<input>` element now raise `WSDL::UnresolvedReferenceError` instead of `NoMethodError`.
- Binding operations not found in the referenced portType now raise `WSDL::UnresolvedReferenceError` instead of `KeyError`.
- Unknown XSD built-in types (e.g., `xsd:nonExistentType`) now raise `WSDL::UnresolvedReferenceError` in strict schema mode instead of being silently treated as simple types.
- Overloaded operations no longer silently overwrite each other. Previously, the second definition just replaced the first.
- Schema resolution now degrades gracefully when `schema_references` strictness is relaxed.

## [1.0.0] — 2026-03-06

Initial public release.

### Client and Service Inspection

- `WSDL::Client` loads WSDL 1.1 documents from URLs or file paths
- Auto-discover services, ports, and operations
- Convenience shortcuts for single-service/single-port WSDLs
- Introspect operation contracts with schema-aware type information
- Generate request templates (minimal or full) for quick prototyping
- WSDL 2.0 documents are detected and rejected with a clear error

### WSDL and XSD Parsing

- Full WSDL 1.1 parsing with recursive XSD import/include resolution
- Strict and relaxed schema import modes for incomplete or malformed schemas
- In-memory LRU cache with configurable TTL and max entries for parsed definitions
- Sandbox path restrictions to prevent path traversal attacks
- Configurable iteration limits for schema import cycles

### Request DSL and Serialization

- Fluent DSL via `operation.prepare { ... }` for building SOAP envelopes
- `tag`, `text`, `cdata`, `comment`, `pi`, `xmlns`, and `attribute` DSL methods
- Request validation against schema contracts (strict and relaxed modes)
- SOAP 1.1 and 1.2 envelope serialization with automatic namespace handling
- Support for document/literal and rpc/literal operation styles
- Element count, attribute count, and depth limits enforcement

### Response Parsing

- Schema-aware type coercion (numeric, boolean, date/time, Base64 binary)
- Smart array handling based on `maxOccurs` schema metadata
- SOAP fault detection and structured parsing for SOAP 1.1 and 1.2
- Raw XML and XPath query access with namespace mapping
- Configurable response size limits to prevent DoS

### WS-Security

- **UsernameToken** authentication with plain text and SHA-1 digest modes
- **Timestamps** with configurable TTL and optional signing
- **X.509 certificate signing** with RSA and EC key support
- Configurable digest algorithms: SHA-1, SHA-256, SHA-512 (SHA-256 default)
- Three key reference methods: BinarySecurityToken, IssuerSerial, SubjectKeyIdentifier
- **Response verification** pipeline with three modes: `disabled`, `if_present`, `required`
- Signature verification with timing-safe digest comparison
- Certificate chain validation against configurable trust stores
- Timestamp freshness validation with clock skew tolerance

### Security Hardening

- **XML safety**: DOCTYPE rejection, NONET parsing, entity expansion prevention
- **Threat detection**: pre-parse scanning for ENTITY, SYSTEM/PUBLIC, deep nesting, and attribute bombing
- **XSW attack protection**: duplicate ID detection, signature location validation, element position checks
- **XPath injection prevention**: NCName validation before ID interpolation into XPath queries
- **Algorithm whitelisting**: unknown algorithms raise `UnsupportedAlgorithmError` (no silent fallbacks)
- **SSRF prevention**: redirect target validation with DNS resolution checks and private network blocking

### HTTP

- Stdlib `net/http` adapter with no external HTTP dependencies
- HTTPS-only by default with configurable TLS settings
- Redirect following with SSRF-safe target validation
- Transparent gzip decompression disabled to prevent gzip bomb attacks
- Configurable timeouts and response size limits

### Configuration and Limits

- Global and per-client configuration with thread-safe defaults
- 11 configurable resource limits (document size, schema count, nesting depth, and more)
- Pluggable logger (defaults to silent `NullLogger`)
- Pluggable HTTP adapter and cache implementations

### Dependencies

- **nokogiri** (>= 1.19.1) for XML parsing and C14N
- **base64** for encoding/decoding
- All cryptography delegated to Ruby's built-in **OpenSSL**

[Unreleased]: https://github.com/rubiii/wsdl/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rubiii/wsdl/releases/tag/v1.0.0
