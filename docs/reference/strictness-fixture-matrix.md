# Strictness Fixture Matrix

This matrix tracks parser behavior for single-file WSDL fixtures under different [`strictness:`](../core/configuration.md#strictness) settings.

The assertions are enforced by `spec/acceptance/strictness_fixture_matrix_spec.rb`.

## Fully Strict Fixtures

These fixtures parse with `Strictness.on` (all checks enabled).

| Fixture |
| --- |
| `wsdl/amazon` |
| `wsdl/authentication` |
| `wsdl/awse` |
| `wsdl/betfair` |
| `wsdl/blz_service` |
| `wsdl/bronto` |
| `wsdl/crowd` |
| `wsdl/daisycon` |
| `wsdl/data_exchange` |
| `wsdl/document_literal_wrapped` |
| `wsdl/economic` |
| `wsdl/email_verification` |
| `wsdl/equifax` |
| `wsdl/geotrust` |
| `wsdl/interhome` |
| `wsdl/iws` |
| `wsdl/jetairways` |
| `wsdl/jira` |
| `wsdl/marketo` |
| `wsdl/namespaced_actions` |
| `wsdl/oracle` |
| `wsdl/ratp` |
| `wsdl/rpc_literal` |
| `wsdl/spyne` |
| `wsdl/stockquote` |
| `wsdl/taxcloud` |
| `wsdl/telefonkatalogen` |
| `wsdl/temperature` |
| `wsdl/xignite` |
| `wsdl/yahoo` |

## Fixtures Requiring Relaxed Strictness

These fixtures fail with `Strictness.on` due to unresolvable schema imports. The missing imports cascade: references can't be resolved and request validation can't verify against incomplete schemas.

| Fixture | Strict Error | Required Settings |
| --- | --- | --- |
| `wsdl/juniper` | `WSDL::SchemaImportError` | `schema_imports: false`, `schema_references: false`, `request_validation: false` |

## Sandbox-Required Fixtures

These fixtures require explicit [`sandbox_paths`](../core/configuration.md#sandbox-paths) for sibling relative imports. The strictness setting does not affect this — `PathRestrictionError` is always raised without the sandbox.

| Fixture | Default Behavior | With `sandbox_paths` |
| --- | --- | --- |
| `wsdl/travelport/system_v32_0/System.wsdl` | `WSDL::PathRestrictionError` | Parses with any strictness |

## See also

- [Configuration](../core/configuration.md)
- [Resolving Imports](../core/resolving-imports.md)
- [Getting Started](../getting_started.md)
