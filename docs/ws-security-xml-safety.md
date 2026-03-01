# XML Parsing Security

This guide covers the library's built-in protections against XML-based attacks.

> **Quick Links:** [Main WS-Security Guide](ws-security.md) | [UsernameToken](ws-security-username-token.md) | [X.509 Signatures](ws-security-signatures.md) | [Troubleshooting](ws-security-troubleshooting.md)

## Overview

The library includes comprehensive protection against XML-based attacks. All XML parsing uses secure defaults that protect against common vulnerabilities including XXE, SSRF, and denial-of-service attacks.

## Protections Enabled by Default

| Protection | Description |
|------------|-------------|
| **XXE Prevention** | External entities are not loaded, preventing file reads and network requests |
| **SSRF Prevention** | Network access during XML parsing is blocked via the `NONET` option |
| **DTD Attack Prevention** | External DTD loading is disabled |
| **Entity Expansion Limits** | Internal entity expansion is limited, protecting against XML bombs |

### XXE (XML External Entity) Prevention

External entities are not loaded, preventing attackers from:

- Reading local files (`file:///etc/passwd`)
- Making network requests through XML parsing
- Exfiltrating data through out-of-band channels

### SSRF (Server-Side Request Forgery) Prevention

Network access during XML parsing is blocked via the `NONET` option, preventing the parser from making outbound requests to attacker-controlled servers.

### DTD Attack Prevention

External DTD loading is disabled, preventing DTD-based attacks including:

- Remote DTD injection
- Parameter entity attacks
- DTD-based denial of service

### Entity Expansion Limits

Internal entity expansion is limited by libxml2's default limits, providing protection against Billion Laughs / XML bomb attacks that attempt to exhaust memory through recursive entity expansion.

## Security Errors

When libxml2 detects a security violation (such as an XML bomb or excessive nesting), the library raises `WSDL::XMLSecurityError`:

```ruby
begin
  doc = WSDL::XML::Parser.parse(untrusted_xml)
rescue WSDL::XMLSecurityError => e
  # Security attack blocked (entity amplification, excessive depth, etc.)
  logger.warn("XML attack blocked: #{e.message}")
  
  # Access the original Nokogiri error for debugging
  puts e.cause  # => #<Nokogiri::XML::SyntaxError: ...>
end
```

Since `XMLSecurityError` inherits from `WSDL::Error`, you can also rescue all WSDL errors together:

```ruby
begin
  client = WSDL::Client.new(untrusted_wsdl)
rescue WSDL::Error => e
  # Catches XMLSecurityError, SignatureVerificationError, etc.
  handle_error(e)
end
```

## Threat Detection and Logging

When parsing WSDL documents from remote sources, the library automatically scans for suspicious patterns and logs warnings:

```ruby
# Threats are automatically logged when parsing remote WSDLs
client = WSDL::Client.new('http://example.com/service?wsdl')
# If the WSDL contains suspicious patterns like DOCTYPE or ENTITY declarations,
# a warning is logged: "Potential XML attack detected: doctype, entity_declaration"
```

### Using the Secure Parser Directly

For custom XML parsing needs, use the secure parser directly:

```ruby
# Strict parsing (raises on malformed XML, XMLSecurityError on attacks)
doc = WSDL::XML::Parser.parse(xml_string)

# Relaxed parsing (tolerates malformed XML, still secure)
doc = WSDL::XML::Parser.parse_relaxed(xml_string)

# Parse with threat callback (for pre-parse pattern detection)
WSDL::XML::Parser.parse_untrusted(xml_string) do |threats|
  if threats.include?(:external_reference)
    raise WSDL::XMLSecurityError, "External references not allowed"
  end
end

# Parse with automatic logging
doc = WSDL::XML::Parser.parse_with_logging(xml_string, logger)
```

## Detected Threat Types

The threat detection system identifies the following patterns:

| Threat | Description | Risk |
|--------|-------------|------|
| `:doctype` | DOCTYPE declaration | Often used in XXE attacks |
| `:entity_declaration` | ENTITY definitions | Used to define XXE payloads |
| `:external_reference` | SYSTEM or PUBLIC identifiers | External resource access |
| `:parameter_entity` | Parameter entity references (`%entity;`) | Advanced XXE techniques |
| `:deep_nesting` | Excessive tag nesting | Potential DoS |
| `:large_attribute` | Very long attribute values | Potential DoS |

## Best Practices

1. **Trust the library's XML parsing** — The XML parser has secure defaults. Don't bypass it with direct Nokogiri calls on untrusted input.

2. **Validate WSDL sources** — Only load WSDL documents from trusted sources. While the library protects against XML attacks, a malicious WSDL could still define unexpected operations or endpoints.

3. **Monitor for threats** — The library logs warnings when suspicious XML patterns are detected. Monitor these logs in production for potential attack attempts.

4. **Handle errors gracefully** — Rescue `WSDL::XMLSecurityError` to handle blocked attacks without crashing your application.

## Internal Protections

The library also includes internal protections that operate transparently:

### XPath Injection Protection

The signature verifier validates element IDs against a strict allowlist pattern (XML NCName) before using them in XPath queries. This prevents attackers from injecting malicious XPath expressions through crafted Reference URIs in signed documents.

### Timing-Safe Comparison

The library uses constant-time string comparison (`OpenSSL.secure_compare`) when verifying cryptographic digests. This prevents timing attacks where an attacker could gradually guess valid digest values by measuring response times.

## Related Documentation

- [Main WS-Security Guide](ws-security.md) — Overview and choosing authentication methods
- [Troubleshooting](ws-security-troubleshooting.md) — Common issues and solutions