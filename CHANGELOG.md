# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- `WSDL.parse` and `WSDL.load` entry points for explicit control over when fetching/parsing happens. `WSDL.parse` returns a frozen, serializable `Definition`. `WSDL.load` restores one from a cached hash.
- `WSDL::Definition` — frozen intermediate representation of everything the library knows about a WSDL service. Provides discovery (`services`, `ports`, `operations`), introspection (`input`, `input_header`, `output`, `output_header`), DSL generation (`to_dsl`), provenance (`sources`, `fingerprint`), and serialization (`to_h`, `to_json`).
- `Client.new` accepts a `Definition` as its first argument, skipping parsing entirely. All `Client` methods route through the `Definition`.
- `Definition#verify!` raises `DefinitionError` if any operations could not be fully resolved. This is the opt-in strict check — parsing itself is always best-effort.
- `Definition#build_issues` provides transparency into operations that could not be fully resolved, with error details for each.
- `WSDL::DefinitionError` — raised by `Definition#verify!`, carries all build issues with `error.issues` for programmatic access.
- Source provenance with SHA-256 content digests for every fetched document. Enables fingerprint-based change detection.
- `Client#definition` accessor returns the `Definition` for the client's WSDL.
- Operation overloading support per WSDL 1.1 §2.4.5. Same-named operations with different input/output messages are stored correctly and disambiguated via `client.operation(:Svc, :Port, :Op, input_name: :InputName)`. WS-I Basic Profile R2304 validation in strict mode raises `OperationOverloadError`.
- `client.services` now includes an `operations` array for each port, listing all available operations. Overloaded operations include `input_name` for disambiguation.
- Extract XML attributes from response elements into the parsed hash with `_`-prefixed keys (e.g., `transactionKey="TXN-123"` → `_transactionKey: "TXN-123"`). Attributes are type-coerced when schema metadata is available.
- One-way operations (no `<output>` message) are now supported. Response contract returns empty elements and `output_style` returns `nil`.
- `strictness:` replaces the `strict_schema` boolean with granular control over 4 validation concerns: `schema_imports`, `schema_references`, `operation_overloading`, `request_validation`. Accepts a hash (`strictness: { schema_imports: false }`), boolean (`strictness: false`), or object.
- All `ResourceLimitError` and strictness error messages now include copy-pasteable fix examples (e.g., `limits: { max_schemas: 51 }`, `strictness: { schema_imports: false }`).
- `limits:` now accepts a hash shorthand (`limits: { max_schemas: 200 }`) in addition to a `Limits` object.
- All 46 XSD built-in types are now explicitly handled by `TypeCoercer`. List types (`IDREFS`, `ENTITIES`, `NMTOKENS`) are now get coerced into arrays.
- `xs:group` (model group) references are now resolved and their elements expanded, mirroring the existing `xs:attributeGroup` support.
- `xs:list` simpleType derivation is now supported for both elements and attributes. List values are parsed by splitting on whitespace, with per-item type coercion based on the `itemType`. Built by joining array values with spaces.
- `xs:union` simpleType derivation is now supported for both elements and attributes. The first `memberType` is used as the base type for coercion.
- `Element#kind` returns `:simple`, `:complex`, or `:recursive` for programmatic dispatch. Included in both `paths` and `tree` contract output.
- `Attribute#to_h` provides a consistent hash representation. Contract `paths` and `tree` now return identical attribute metadata including `name`, `type`, `required`, and `list`.
- `operation.invoke { ... }` accepts an optional block, combining `prepare` and `invoke` into a single call.
- `operation.to_xml(pretty: true)` for formatted XML output. Request XML is compact by default.

### Changed

- `Client.new` only accepts a `Definition` instance. Use `WSDL.parse(source)` to create one. Parse-time options (`strictness:`, `limits:`, `sandbox_paths:`) belong on `WSDL.parse`, runtime options (`strictness:`, `limits:`) on `Client.new`.
- Removed built-in parse cache (`WSDL.cache`, `Cache` class, `cache:` parameter on `Client.new` and `WSDL.parse`). `Definition` is serializable via `to_h`/`to_json`/`from_h` — cache at the Definition level instead (file, Redis, etc.).
- Removed `cache_key` contract from HTTP clients. Custom clients no longer need to implement `#cache_key`.
- Removed `InvalidHTTPAdapterError` (was only used for `cache_key` validation).
- `WSDL::HTTPAdapter` renamed to `WSDL::HTTP::Client`. Config, RedirectGuard, and Response moved into the `WSDL::HTTP` namespace. `WSDL.http_adapter` accessor renamed to `WSDL.http_client`.
- `WSDL::HTTPResponse` renamed to `WSDL::HTTP::Response`.
- Removed `WSDL.strictness` and `WSDL.limits` global setters. Pass `strictness:` and `limits:` as kwargs on `WSDL.parse` or `Client.new` instead. Defaults are sensible — no configuration needed for most use cases.
- I/O concerns extracted from `Parser` into `WSDL::Resolver` namespace (`Resolver::Source`, `Resolver::Loader`, `Resolver::Importer`). Old `Source`, `Parser::Resolver`, and `Parser::Importer` classes removed.
- Element tree building is always best-effort. Unresolvable types, missing elements, and resource limits are recorded as build issues rather than raising exceptions. Operations are included in the `Definition` with whatever data was successfully collected.
- `BindingOperation#find_input_child_nodes` returns `[]` for missing `<input>` instead of raising.
- `PortTypeOperation#input` returns `nil` for missing `<input>` (matching how `output` already handled missing `<output>`).
- `MessageParts` records issues via an issues pipeline instead of raising for missing messages and header references.
- `ElementBuilder` always uses lenient schema resolution (`find_*` instead of `fetch_*`) and records issues via the pipeline. Nesting depth and element/attribute count limits are recorded as resource limit issues.
- Removed `format_xml` option from `Config`, `Client`, and `Operation`. Request XML is now always compact. Use `operation.to_xml(pretty: true)` when formatted output is needed.
- `response.xml` replaces `response.raw`.
- Removed `response.envelope_hash` (and `to_envelope_hash` alias) from the public API. Use `response.body` and `response.header` for schema-aware access, or `response.doc` for direct XML access.
- Removed `response.xpath`. Use `response.doc.xpath` instead.

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

- Stdlib `net/http` client with no external HTTP dependencies
- HTTPS-only by default with configurable TLS settings
- Redirect following with SSRF-safe target validation
- Transparent gzip decompression disabled to prevent gzip bomb attacks
- Configurable timeouts and response size limits

### Configuration and Limits

- Global and per-client configuration with thread-safe defaults
- 11 configurable resource limits (document size, schema count, nesting depth, and more)
- Pluggable logger (defaults to silent `NullLogger`)
- Pluggable HTTP client

### Dependencies

- **nokogiri** (>= 1.19.1) for XML parsing and C14N
- **base64** for encoding/decoding
- All cryptography delegated to Ruby's built-in **OpenSSL**

[Unreleased]: https://github.com/rubiii/wsdl/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rubiii/wsdl/releases/tag/v1.0.0
