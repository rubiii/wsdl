---
paths:
  - "spec/**/*_spec.rb"
  - "spec/support/**/*.rb"
---

# Test Conventions

## Test Placement

- **Unit tests** (`spec/wsdl/`): Mirror `lib/wsdl/` structure. Test individual classes in isolation.
- **Acceptance tests** (`spec/acceptance/`): Full parsing pipeline with real WSDLs. No network, no mock server.
- **Integration tests** (`spec/integration/`): Full HTTP round-trips against `TestService` mock server. Auto-tagged `:test_service`.
- **Conformance tests** (`spec/conformance/`): W3C/OASIS spec compliance. Each test references an assertion ID and spec URL.
- **Property tests** (`spec/property/`): Rantly-based generative testing for invariants.
- **Performance tests** (`spec/performance/`): Allocation budgets and timing. Auto-tagged `:performance`. Tag wall-time examples with `:timing`. Use `count_allocations { }` for deterministic allocation measurement.

## Helpers

- Load fixtures with `fixture('wsdl/amazon')` — never `File.read` a fixture path directly
- Unit/acceptance/conformance tests use `http_mock` for HTTP (a custom hash-based adapter, not WebMock)
- Integration tests use `WSDL::TestService` which manages a real WEBrick server
- Build mock schema elements with `schema_element('Name', type: 'xsd:string', singular: true, children: [...])` and `schema_attribute('id', type: 'xsd:int')`
- Inspect contracts with `request_template(operation, section: :body)` and `request_body_paths(operation)`
- XML assertions: `expect(doc).to be_equivalent_to(expected).respecting_element_order`

## Conformance Tests

Each test references a spec assertion ID and URL:

```ruby
# https://www.w3.org/TR/2000/NOTE-SOAP-20000508/#_Toc478383494
it 'S11-ENV-1: Envelope element is present' do
```

Format: `PREFIX-SECTION-NUMBER` (e.g., `S11-ENV-1`, `S12-FLT-3`, `W11-MSG-2`). No zero-padding.

## Property Tests

Use `property_of { }.check(trial_count)` with Rantly generators (`range`, `choose`, `sized`, `string`). Assert invariants (parser doesn't crash, round-trip preserves data), not output shape. Trial count from `ENV['PROPERTY_TRIALS']` (default 100).

## Parser Edge Cases

For testing parser behavior with custom WSDL XML, use the Tempfile pattern:

```ruby
def write_wsdl_file(wsdl_xml)
  file = Tempfile.new(['test', '.wsdl'])
  file.write(wsdl_xml)
  file.flush
  tempfiles << file
  file.path
end
```

Clean up in `after { tempfiles.each(&:close!) }`.

## Multi-File WSDLs

Multi-file WSDLs use `manifest.yml` files that map HTTP import URLs to local fixtures. Load via `RoundtripCandidates` or by calling `http_mock.fake_request(url, fixture_path)` for each mapping.

## Coverage

SimpleCov enforces: 95% line, 80% branch overall, 80% line per-file. Never skip coverage.
