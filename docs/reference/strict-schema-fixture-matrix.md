# Strict Schema Fixture Matrix

This matrix tracks parser behavior for integration fixtures under [`strict_schema`](../core/configuration.md#strict-schema-mode):

- `strict_schema: true`
- `strict_schema: false`

The assertions are enforced by `spec/integration/strict_schema_fixture_matrix_spec.rb`.

## Strict-Ready Fixtures

These fixtures parse in both strict and relaxed mode.

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

## Relaxed-Only Fixtures

These fixtures fail in strict mode and parse in relaxed mode.

| Fixture | Strict Error |
| --- | --- |
| `wsdl/juniper` | `WSDL::SchemaImportError` |

## Sandbox-Required Fixtures

These fixtures require explicit [`sandbox_paths`](../core/configuration.md#sandbox-paths) for sibling relative imports.

| Fixture | Default Behavior | With `sandbox_paths` |
| --- | --- | --- |
| `wsdl/travelport/system_v32_0/System.wsdl` | `WSDL::PathRestrictionError` in strict and relaxed mode | Parses in strict and relaxed mode |

## See also

- [Configuration](../core/configuration.md)
- [Resolving Imports](../core/resolving-imports.md)
- [Getting Started](../getting_started.md)
