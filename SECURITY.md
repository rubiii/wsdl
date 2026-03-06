# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | No        |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Please email [security@rubiii.com](mailto:security@rubiii.com) with:

- A description of the vulnerability
- Steps to reproduce or a proof of concept
- Any relevant WSDL fixtures or payloads
- The impact you believe this has

You will receive a response within 48 hours acknowledging your report. We will work with
you to understand the issue and coordinate a fix and disclosure timeline.

## Disclosure Policy

- We will confirm receipt of your report within 48 hours
- We will provide an estimated timeline for a fix within 7 days
- We will notify you when the fix is released
- We ask that you do not publicly disclose the issue until a fix is available

## Scope

This policy applies to the `wsdl` Ruby gem and its security-sensitive components,
including but not limited to:

- XML parsing and XXE protection
- WS-Security (signatures, encryption, tokens)
- SSRF protection in HTTP handling
- Input validation and resource limits
