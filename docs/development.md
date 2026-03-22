# Development Guidelines

Coding standards and conventions for the WSDL library. These apply to all contributions.

## Code Style

Code style is enforced by RuboCop. See [`.rubocop.yml`](../.rubocop.yml) for the full configuration.

```sh
bundle exec rake lint                        # Runs all linting tasks
bundle exec rake lint:ruby                   # Runs RuboCop
bundle exec rake lint:ruby:autocorrect       # Autofix safe RuboCop offenses
bundle exec rake lint:ruby:autocorrect_all   # Autofix all RuboCop offenses (safe + unsafe)
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

## See also

- [Testing](testing.md)
- [Specifications](reference/specifications.md)
- [Error Hierarchy](reference/errors.md)
- [WS-Security Overview](security/ws-security.md)
