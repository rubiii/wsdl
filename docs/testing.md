# Testing

The test suite is organized in layers: unit, acceptance, integration, conformance, property-based, and performance tests. All checks run with `bundle exec rake ci`.

## Running Tests

| Command | Purpose |
|---------|---------|
| `bundle exec rspec` | Run all tests |
| `bundle exec rake benchmark` | Performance benchmarks (IPS, tracked in CI) |
| `bundle exec rake benchmark:specs` | Performance specs (allocation budgets + timing) |
| `bundle exec rake profile:wall` | Wall-time StackProf profile |
| `bundle exec rake profile:cpu` | CPU StackProf profile |
| `bundle exec rake profile:objects` | Object allocation StackProf profile |
| `bundle exec rake profile:all` | Run all three profiles |
| `bundle exec rake profile:report[dump]` | Print a StackProf dump report |
| `bundle exec rake profile:method[dump,Method]` | Drill into a method in a StackProf dump |
| `bundle exec rake ci` | Full CI (lint + docs + tests) |

Environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEBUG` | unset | Enable debug logging during test runs |
| `PROPERTY_TRIALS` | `100` | Number of trials for property-based tests |
| `SPEC_TIMEOUT` | `30` | Per-example timeout in seconds for `:with_timeout` tagged specs |

## Test Structure

```
spec/
├── wsdl/           # Unit tests (mirrors lib/wsdl/)
├── acceptance/     # Acceptance tests (real WSDLs, no network)
├── integration/    # Integration tests (live mock services)
├── conformance/    # W3C/OASIS specification conformance
├── property/       # Property-based tests (Rantly)
├── performance/    # Performance tests (allocation budgets, timing)
├── fixtures/       # WSDLs, responses, security certs, parser edge cases
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
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/blz_service')) }

  it 'creates an example request' do
    operation = client.operation(:BLZService, :BLZServiceSOAP11port_http, :getBank)

    expect(request_template(operation, section: :body)).to eq(
      getBank: { blz: 'string' }
    )
  end
end
```

This includes the exhaustive schema round-trip test (`exhaustive_roundtrip_spec.rb`) which auto-generates one test per operation across all fixture WSDLs, verifying `parse(build(hash)) == hash` with full hashes and nillable elements.

Multi-file WSDLs (with HTTP imports) are loaded via `manifest.yml` files that map import URLs to local fixture files.

## Integration Tests

Integration tests in `spec/integration/` perform full HTTP round-trips against live mock services. The `:test_service` metadata is applied automatically to all specs in this directory — no manual tagging needed.

```ruby
RSpec.describe 'BLZService' do
  subject(:client) { WSDL::Client.new(WSDL.parse(service.wsdl_url)) }

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

All property specs are automatically tagged with `:with_timeout` metadata, which wraps each example in a `Timeout.timeout` call (default: 30 seconds, override with `SPEC_TIMEOUT`). This prevents generative tests from consuming unbounded memory or CPU when Rantly picks large WSDL definitions. The tag can also be applied to individual examples in other spec directories:

```ruby
it 'something potentially expensive', :with_timeout do
  # ...
end
```

## Performance Tests

Performance tests in `spec/performance/` guard against allocation regressions and timing degradation. They run as part of the normal test suite — every `bundle exec rspec` and `rake ci` run includes them, so regressions are caught immediately during development.

```sh
bundle exec rake benchmark:specs                               # Run only performance specs
```

Two types of specs:

**Allocation-budget specs** are deterministic — they count Ruby object allocations, not wall time. A component exceeding its allocation ceiling fails the build.

**Timing specs** (tagged `:timing`) measure wall-clock time with generous thresholds (typically 5-10x headroom over actual). If a timing test ever becomes flaky on a specific CI runner, exclude it with `--tag ~timing` as a targeted fix.

```ruby
RSpec.describe 'Parse pipeline performance' do
  let(:wsdl) { fixture('wsdl/economic') }

  it 'stays within allocation budget' do
    allocs = count_allocations { WSDL::Parser.parse(wsdl, http_mock) }
    expect(allocs).to be < 1_000_000
  end

  it 'parses within acceptable time', :timing do
    parse_time = Benchmark.realtime { WSDL::Parser.parse(wsdl, http_mock) }
    expect(parse_time).to be < 2.0
  end
end
```

The `count_allocations` helper (from `spec/support/allocation_helpers.rb`) disables GC and measures `GC.stat(:total_allocated_objects)` delta for deterministic results.

### Profiling

StackProf profiling tasks provide a smooth workflow for investigating performance:

```sh
bundle exec rake profile:wall                                  # Wall-time profile
bundle exec rake profile:cpu                                   # CPU profile
bundle exec rake profile:objects                               # Object allocation profile
bundle exec rake profile:all                                   # All three modes
bundle exec rake profile:report[tmp/stackprof-large-wall.dump] # Print top methods
bundle exec rake profile:method[tmp/stackprof-large-wall.dump,WSDL::XML::Element#freeze]
```

Profile dumps are written to `tmp/` and can be inspected with `stackprof` directly or via the Rake helpers.

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
| `spec/fixtures/wsdl/` | 45+ real-world WSDL documents (single-file and multi-file with `manifest.yml`) |
| `spec/fixtures/response/` | Sample SOAP response XML |
| `spec/fixtures/security/` | Signed envelopes, certificates |
| `spec/fixtures/parser/` | Parser edge-case fixtures (malicious payloads, duplicate definitions, QName collisions, unresolved references) |

The `fixture()` helper resolves paths with glob matching:

```ruby
fixture('wsdl/blz_service')  # => spec/fixtures/wsdl/blz_service.wsdl
```

Multi-file WSDLs use a `manifest.yml` that maps HTTP import URLs to local files, used by both acceptance specs and the exhaustive round-trip test.

## Test Helpers

| Helper | File | Purpose |
|--------|------|---------|
| `fixture(path)` | `spec/support/fixture.rb` | Load fixture files by path |
| `schema_element(...)` | `spec/support/schema_element_helper.rb` | Build mock `WSDL::XML::Element` instances |
| `schema_attribute(...)` | `spec/support/schema_element_helper.rb` | Build mock `WSDL::XML::Attribute` instances |
| `request_body_paths(op)` | `spec/support/contract_helper.rb` | Inspect request contract paths |
| `request_template(op)` | `spec/support/contract_helper.rb` | Inspect request contract template |
| `http_mock` | `spec/support/http_mock.rb` | Hash-based HTTP stubbing |
| `count_allocations { }` | `spec/support/allocation_helpers.rb` | Measure object allocations in a block |
| `RoundtripCandidates` | `spec/support/roundtrip_candidates.rb` | Shared candidate discovery and manifest loading for round-trip tests |

## See also

- [Getting Started](getting_started.md)
- [Specifications](reference/specifications.md)
