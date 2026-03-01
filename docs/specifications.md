# Specifications Reference

This library implements several W3C and OASIS standards. All code must conform to these official specifications. Use the URLs below for reference when implementing features or troubleshooting interoperability issues.

## Core Standards

| Specification | Version | URL |
|---------------|---------|-----|
| **WSDL** | 1.1 | https://www.w3.org/TR/wsdl |
| **SOAP** | 1.1 | https://www.w3.org/TR/2000/NOTE-SOAP-20000508/ |
| **SOAP** | 1.2 Part 1 | https://www.w3.org/TR/soap12-part1/ |
| **SOAP** | 1.2 Part 2 | https://www.w3.org/TR/soap12-part2/ |
| **XML Schema (XSD)** | 1.1 Part 1: Structures | https://www.w3.org/TR/xmlschema11-1/ |
| **XML Schema (XSD)** | 1.1 Part 2: Datatypes | https://www.w3.org/TR/xmlschema11-2/ |

## WS-Security Standards (OASIS)

| Specification | Version | URL |
|---------------|---------|-----|
| **WS-Security SOAP Message Security** | 1.1.1 | https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-SOAPMessageSecurity-v1.1.1-os.html |
| **WS-Security UsernameToken Profile** | 1.1.1 | https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-UsernameTokenProfile-v1.1.1-os.html |
| **WS-Security X.509 Certificate Token Profile** | 1.1.1 | https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-x509TokenProfile-v1.1.1-os.html |
| **WS-SecurityPolicy** | 1.3 | https://docs.oasis-open.org/ws-sx/ws-securitypolicy/v1.3/ws-securitypolicy.html |

## XML Security Standards (W3C)

| Specification | Version | URL |
|---------------|---------|-----|
| **XML Signature Syntax and Processing** | 1.1 | https://www.w3.org/TR/xmldsig-core1/ |
| **XML Signature Best Practices** | — | https://www.w3.org/TR/xmldsig-bestpractices/ |
| **Canonical XML** | 1.1 | https://www.w3.org/TR/xml-c14n11/ |
| **Exclusive XML Canonicalization** | 1.0 | https://www.w3.org/TR/xml-exc-c14n/ |

## WS-Addressing Standards (W3C)

| Specification | Version | URL |
|---------------|---------|-----|
| **WS-Addressing Core** | 1.0 | https://www.w3.org/TR/ws-addr-core/ |
| **WS-Addressing SOAP Binding** | 1.0 | https://www.w3.org/TR/ws-addr-soap/ |

## Usage Notes

- **WSDL 1.1** is the primary version supported. WSDL 2.0 has different semantics and is not widely adopted.
- **SOAP 1.1 vs 1.2**: The library supports both. The WSDL document determines which version to use.
- **WS-Security 1.1.1** is the latest maintenance release with errata corrections.
- **XML Signature 1.1** is preferred over 1.0 for new implementations.
- **Exclusive C14N** is required for signing XML fragments (used in WS-Security signatures).