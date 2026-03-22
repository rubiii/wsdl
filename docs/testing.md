# Testing

The test suite is organized in layers: unit, acceptance, integration, conformance, and property-based tests. All checks run with `bundle exec rake ci`.

## Running Tests

| Command | Purpose |
|---------|---------|
| `bundle exec rspec` | Run all tests |
| `bundle exec rake benchmark` | Performance benchmarks |
| `bundle exec rake ci` | Full CI (lint + docs + tests) |

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEBUG` | unset | Enable debug logging during test runs |
| `PROPERTY_TRIALS` | `100` | Number of trials for property-based tests |

## Test Structure

```
spec/
├── wsdl/           # Unit tests (mirrors lib/wsdl/)
├── acceptance/     # Acceptance tests (real WSDLs, no network)
├── integration/    # Integration tests (live mock services)
├── conformance/    # W3C/OASIS specification conformance
├── property/       # Property-based tests (Rantly)
├── fixtures/       # WSDLs, responses, security certs
└── support/        # Helpers, mock server, test infrastructure
```

## Unit Tests

Unit tests live in `spec/wsdl/` and mirror the `lib/wsdl/` directory structure. They test individual classes in isolation using real fixture WSDLs and mock schema elements.

```ruby
RSpec.describe WSDL::Response::Parser do
  it 'parses an XML string into a Hash' do
    xml = '<Root><Child>content</Child></Root>'
    result = described_class.parse(xml)

    expect(result).to eq({ Root: { Child: 'content' } })
  end
end
```

## Acceptance Tests

Acceptance tests in `spec/acceptance/` verify the full parsing pipeline (WSDL → schema resolution → element building → contracts) against real-world WSDLs. No network calls, no mock server.

```ruby
RSpec.describe 'BLZService' do
  subject(:client) { WSDL::Client.new fixture('wsdl/blz_service') }

  it 'creates an example request' do
    operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

    expect(request_template(operation, section: :body)).to eq(
      getBank: { blz: 'string' }
    )
  end
end
```

These tests cover service discovery, contract shapes, request XML generation, and edge cases across diverse WSDL patterns.

## Integration Tests

Integration tests in `spec/integration/` perform full HTTP round-trips against live mock services. The `:test_service` metadata is applied automatically to all specs in this directory — no manual tagging needed.

```ruby
RSpec.describe 'BLZService' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:blz_service] }

  before { service.start }

  it 'returns bank details for a known BLZ' do
    operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

    operation.prepare do
      body do
        tag('getBank') { tag('blz', '70070010') }
      end
    end
    response = operation.invoke

    expect(response.body).to eq(
      getBankResponse: {
        details: { bezeichnung: 'Deutsche Bank', bic: 'DEUTDEMM', ort: 'München', plz: '80271' }
      }
    )
  end
end
```

## Mock Server

Service definitions are declared inline at the top of each integration spec:

```ruby
WSDL::TestService.define(:blz_service, wsdl: 'wsdl/blz_service') do
  operation :getBank do
    on blz: '70070010' do
      { details: { bezeichnung: 'Deutsche Bank', bic: 'DEUTDEMM', ort: 'München', plz: '80271' } }
    end

    on blz: '20050550' do
      { details: { bezeichnung: 'Hamburger Sparkasse', bic: 'HASPDEHHXXX', ort: 'Hamburg', plz: '20454' } }
    end
  end
end
```

A shared WEBrick server starts on demand and shuts down after the suite. `Response::Builder` handles SOAP serialization including RPC/literal wrapping. Definitions are validated against the WSDL schema at load time.

## Conformance Tests

Tests in `spec/conformance/` verify compliance with SOAP 1.1, SOAP 1.2, WSDL 1.1, and XML Schema specifications. Each test references an assertion ID documented in `W3C_CONFORMANCE_ASSERTIONS.md`.

```ruby
RSpec.describe 'SOAP 1.1 conformance' do
  # S11-ENV-001: Envelope element must use the SOAP 1.1 namespace
  it 'uses the correct SOAP 1.1 envelope namespace' do
    expect(parsed_envelope.root.namespace.href)
      .to eq('http://schemas.xmlsoap.org/soap/envelope/')
  end
end
```

## Property-Based Tests

[Rantly](https://github.com/rantly-rb/rantly)-based generative testing with configurable trial count (default: 100, override with `PROPERTY_TRIALS`).

Property tests live in `spec/property/`:

**Security invariants** (`spec/property/xml_parser_spec.rb`): DOCTYPE rejection across randomized casing and positions, XXE payload variations, crash resistance for random byte sequences.

**Round-trip fidelity** (`spec/property/response_roundtrip_spec.rb`): for randomly chosen operations from fixture WSDLs, generates random response hashes (all XSD types, nillable elements, variable-length arrays, XML-special characters) and verifies `parse(build(hash)) == hash`.

## Coverage

SimpleCov enforces minimum coverage on every run:

| Metric | Minimum |
|--------|---------|
| Line coverage (overall) | 95% |
| Branch coverage (overall) | 80% |
| Line coverage (per file) | 80% |

Coverage is grouped by module (Security, Parser, Request, Response, XML). View the report at `coverage/index.html` after running tests.

## Fixtures

| Directory | Contents |
|-----------|----------|
| `spec/fixtures/wsdl/` | 45+ real-world WSDL documents |
| `spec/fixtures/response/` | Sample SOAP response XML |
| `spec/fixtures/security/` | Signed envelopes, certificates |

The `fixture()` helper resolves paths with glob matching:

```ruby
fixture('wsdl/blz_service')  # => spec/fixtures/wsdl/blz_service.wsdl
```

Edge-case fixtures include `malicious/` (attack payloads), `duplicate_definitions/` (conflicting imports), `qname_collisions/` (namespace ambiguity), and `nillable_elements/` (xsi:nil handling).

## Test Helpers

| Helper | File | Purpose |
|--------|------|---------|
| `fixture(path)` | `spec/support/fixture.rb` | Load fixture files by path |
| `schema_element(...)` | `spec/support/schema_element_helper.rb` | Build mock `WSDL::XML::Element` instances |
| `schema_attribute(...)` | `spec/support/schema_element_helper.rb` | Build mock `WSDL::XML::Attribute` instances |
| `request_body_paths(op)` | `spec/support/contract_helper.rb` | Inspect request contract paths |
| `request_template(op)` | `spec/support/contract_helper.rb` | Inspect request contract template |
| `http_mock` | `spec/support/http_mock.rb` | WebMock-based HTTP stubbing |

## See also

- [Getting Started](getting_started.md)
- [Specifications](reference/specifications.md)
