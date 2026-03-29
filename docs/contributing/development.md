# Development Guidelines

Coding standards and conventions for the WSDL library. These apply to all contributions.

## Code Style

Code style is enforced by RuboCop. See [`.rubocop.yml`](../../.rubocop.yml) for the full configuration.

```sh
bundle exec rake lint       # Run all linting tasks
bundle exec rake lint:fix   # Autofix all RuboCop offenses (safe + unsafe)
```

When a linting rule conflicts with clear code:

1. Try refactoring — extract a method, simplify logic, etc.
2. If the code is already clean, add an inline `rubocop:disable` comment.
3. If inline disables accumulate for the same rule, relax it in `.rubocop.yml`.

Never degrade code quality (shorten docs, remove blank lines, merge logic) just to satisfy a metric.

## Documentation

YARD documentation completeness is enforced by CI. All public methods must be documented.

```sh
bundle exec rake yard         # Generate docs
bundle exec rake yard:audit   # Check coverage and warnings
```

Detailed user docs live in `docs/` folder; keep README brief.

## Testing

Every public method must be tested. Coverage is enforced by SimpleCov (95% line, 80% branch). See the [testing guide](testing.md) for the full test structure, fixtures, helpers, and how to write each type of test.

```sh
bundle exec rspec              # Run all tests
bundle exec rake ci            # Run all checks (lint + docs + tests)
```

## Specifications

This library implements several W3C and OASIS standards. Local markdown copies of these specifications are available for reference but are not committed to the repository (the original documents are copyrighted). After cloning, run:

```sh
bundle exec rake specifications:update      # Download and convert all specs
bundle exec rake specifications:check       # Check if local copies are up to date
bundle exec rake specifications:reconvert   # Re-download and reconvert all specs
```

The specs are stored in `docs/reference/specs/` with a `manifest.yml` that tracks URLs, checksums, and freshness. See [Specifications](../reference/specifications.md) for the full list of standards this library targets.

## See also

- [Testing](testing.md)
- [Specifications](../reference/specifications.md)
- [Error Hierarchy](../reference/errors.md)
- [WS-Security Overview](../security/ws-security.md)
