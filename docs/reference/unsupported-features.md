# Unsupported Features

This page lists features that are explicitly **out of scope** for the current release.
Where applicable, the error class raised when a feature is encountered is noted.

## WSDL 2.0

WSDL 2.0 (namespace `http://www.w3.org/ns/wsdl`) is not supported. The library targets WSDL 1.1 exclusively.
WSDL 2.0 documents are detected at parse time and rejected with `UnsupportedWSDLVersionError`.

WSDL 2.0 is a ground-up redesign that shares very little with 1.1 — different element names (`description`
vs. `definitions`, `interface` vs. `portType`), a different type system binding model, and HTTP binding
semantics that blur the line with REST. Supporting both versions would effectively mean two separate parsers
with no shared code. In practice, WSDL 2.0 saw almost no industry adoption. The W3C published it in 2007,
but the SOAP ecosystem had already standardized on 1.1 and never migrated.

## RPC/encoded

SOAP operations using `rpc/encoded` style are not supported. The library supports `document/literal` and
`rpc/literal`. Attempting to use an `rpc/encoded` operation raises `UnsupportedStyleError`.

RPC/encoded uses SOAP encoding rules (Section 5 of the SOAP 1.1 spec) instead of XML Schema for
serialization. This means types are encoded inline with `xsi:type` attributes and multi-ref `href`
pointers rather than being validated against an XSD. The entire request validation and serialization
pipeline in this library is built around schema-driven contracts, which is fundamentally incompatible
with SOAP encoding. WS-I Basic Profile 1.0 (2004) deprecated RPC/encoded and it is effectively extinct
in modern services.

## EncryptedKey Token References

WS-Security responses may reference the signing certificate via an `EncryptedKey` element inside
`SecurityTokenReference`. This library supports three reference methods:

- Direct `BinarySecurityToken` reference
- `IssuerSerial` (X.509 issuer name + serial number)
- `SubjectKeyIdentifier` (SKI)

`EncryptedKey`-based references are not resolved. If encountered during response verification, the
verifier will raise an error because the signing certificate cannot be located.

Resolving `EncryptedKey` references requires implementing XML Encryption decryption (at least
`xenc:EncryptedKey` unwrapping with RSA-OAEP or RSA-1.5) just to obtain the symmetric key, which is
then used to locate or decrypt the certificate reference. This pulls in the full XML Encryption spec
as a dependency for what is essentially a certificate lookup mechanism. The three supported reference
methods cover the majority of real-world X.509-based WS-Security deployments.

**Workaround:** If the peer service uses `EncryptedKey` references exclusively, you can disable response
verification (`verify_response mode: :disabled`) and handle signature validation externally.

## WS-SecurityPolicy

The library does not parse WS-SecurityPolicy assertions embedded in WSDL documents. Security must be
configured manually via the `ws_security` DSL inside `operation.prepare`.

WS-SecurityPolicy is a large specification (90+ pages) that defines a declarative policy language for
expressing security requirements in WSDL. Implementing it requires a policy intersection engine,
alternative resolution, and a mapping layer that translates abstract policy assertions into concrete
security header configurations. Manual configuration via the `ws_security` DSL gives users explicit
control over exactly what gets sent, which is easier to debug when working with non-compliant services.

**Workaround:** Inspect the WSDL manually (or consult the service documentation) to determine the
required security configuration, then apply it via the `ws_security` block.

## SOAP with Attachments (SwA) and MTOM

SOAP Messages with Attachments (SwA) and MTOM (Message Transmission Optimization Mechanism) are not
supported. The library processes SOAP envelopes as plain XML.

Both SwA and MTOM use multipart MIME packaging to send binary data alongside the SOAP envelope.
Supporting them requires a MIME parser, content-ID resolution for `xop:Include` references, and changes
to the HTTP client contract to handle multipart request/response bodies instead of plain XML strings.
This is a fundamentally different transport model that cuts across the entire request/response pipeline.
Services that need binary transfer increasingly use REST-based file endpoints or base64 encoding within
the SOAP body, reducing the practical demand for SwA/MTOM.

## XML Encryption

WS-Security encryption (`xenc:EncryptedData`, `xenc:EncryptedKey` for payload encryption) is not
supported. The library handles signing and signature verification only.

XML Encryption is a complex specification with its own key agreement, key wrapping, and bulk encryption
algorithms. It interacts with XML Signature in subtle ways (sign-then-encrypt vs. encrypt-then-sign
ordering) and requires careful handling of encrypted element replacement in the DOM. Most modern SOAP
services rely on TLS for transport-level confidentiality instead of message-level encryption, making
XML Encryption increasingly rare outside of legacy government and financial systems.

## WS-Addressing (Partial)

WS-Addressing headers can be **signed** when present (all 7 standard headers are covered), but the
library does not generate or manage WS-Addressing headers automatically. Users must add addressing
headers manually via the request DSL if the service requires them.

Auto-generating WS-Addressing headers requires knowledge of the service's addressing policy (which
headers are required, what `ReplyTo` and `FaultTo` endpoints to use, whether `MessageID` correlation
is expected). This is tightly coupled to the deployment topology and cannot be reliably inferred from
the WSDL alone. Signing support is provided because it is a mechanical operation that does not require
policy decisions.

## See Also

- [Error Hierarchy](errors.md) for the full list of error classes
- [Specifications](specifications.md) for supported standards
- [WS-Security Overview](../security/ws-security.md)
- [Getting Started](../getting_started.md)
