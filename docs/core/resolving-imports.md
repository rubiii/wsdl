# Resolving Imports

WSDL import resolution covers:

- `wsdl:import`
- `xsd:import`
- `xsd:include`

Resolution uses the parent document location for relative paths and is constrained by sandbox rules.

## Strict vs Best-Effort Behavior

Set behavior through [`strictness:`](configuration.md#strictness).

```ruby
# Strict (default)
WSDL.parse('/app/wsdl/service.wsdl', strictness: Strictness.on)

# Best effort
WSDL.parse('/app/wsdl/service.wsdl', strictness: Strictness.off)
```

`Strictness.on`:

- Recoverable schema import failures raise `WSDL::SchemaImportError`.

`Strictness.off`:

- Recoverable schema import failures are logged and skipped.
- Parsing can proceed with partial schema metadata.
- Structural WSDL reference errors still raise (best effort does not downgrade binding/message integrity checks).

Fatal security/path errors still raise in both modes.

## Fatal Errors That Always Raise

- `WSDL::PathRestrictionError`
- `WSDL::UnresolvableImportError`
- `WSDL::XMLSecurityError`

## Sandbox Behavior

Without explicit [`sandbox_paths`](configuration.md#sandbox-paths), file-based WSDLs are sandboxed to the WSDL directory.

```ruby
definition = WSDL.parse('/app/wsdl/system/service.wsdl')
```

For sibling directories, configure both paths:

```ruby
definition = WSDL.parse(
  '/app/wsdl/system/service.wsdl',
  sandbox_paths: ['/app/wsdl/system', '/app/wsdl/common']
)
```

## Common Recovery Steps

1. Switch to `strictness: Strictness.off` for a quick best-effort parse.
2. Configure missing sandbox paths for local relative imports.
3. Confirm import URLs are reachable.
4. Fix malformed external XSD sources or vendor-provided schema bundles.

## Request Validation Impact

Strict request validation depends on operation-relevant schema completeness.

- In strict mode, incomplete operation metadata causes request validation errors.
- In non-strict mode, known parts are validated and unknown parts are tolerated.

## See also

- [Getting Started](../getting_started.md)
- [Error Hierarchy](../reference/errors.md)
- [Configuration](configuration.md)
- [Strictness Fixture Matrix](../reference/strictness-fixture-matrix.md)
