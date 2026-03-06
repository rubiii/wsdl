# Contributing to WSDL

Thanks for your interest in contributing! This guide covers everything you need to get started.

Please note that this project is released with a [Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to abide by its terms.

## Security Vulnerabilities

**Do not open a public issue for security vulnerabilities.** Instead, email
[security@rubiii.com](mailto:security@rubiii.com) with a description of the issue, steps to reproduce,
and any relevant WSDL fixtures. You will receive a response within 48 hours.

## Getting Started

Requirements:

- Ruby 3.2+
- Bundler

```sh
git clone https://github.com/rubiii/wsdl.git
cd wsdl
bundle install
bundle exec rake ci   # Run all checks (RuboCop + RSpec)
```

Useful commands:

```sh
bundle exec rspec            # Run tests only
bundle exec rake benchmark   # Run performance benchmarks
bundle exec rubocop          # Run linter only
bundle exec rubocop -a       # Autofix lint offenses
bundle exec yard             # Generate YARD documentation
bundle exec rake yard:audit  # Run yard audit only
```

## How to Contribute

### Bug Reports

Open an [issue](https://github.com/rubiii/wsdl/issues) with:

- A minimal WSDL fixture that reproduces the problem
- The SOAP version (1.1 or 1.2) if relevant
- Ruby version and `wsdl` gem version
- Steps to reproduce and actual vs. expected behavior

### Feature Requests

Open an issue to discuss the idea before writing code. This avoids wasted effort
if the feature doesn't fit the project's scope.

### Bug Fixes

1. Write a failing test that demonstrates the bug
2. Fix the bug
3. Run `bundle exec rake ci` to verify everything passes

### Documentation

Improvements to YARD docs, the `docs/` folder, or the README are always welcome.
Run `bundle exec yard` to verify documentation compiles without warnings.

## Pull Request Guidelines

1. Fork the repository and create a branch from `main`
2. Keep each PR focused on a single concern
3. Include tests for any behavior changes
4. Ensure `bundle exec rake ci` passes (RSpec + RuboCop + YARD)
5. Update documentation if your change affects the public API
6. Write clear commit messages that explain *why*, not just *what*

## Code Style

The project uses RuboCop for style enforcement.
See `.rubocop.yml` for the full configuration.

## Testing

- Test directory structure mirrors `lib/`: `spec/wsdl/` corresponds to `lib/wsdl/`
- Integration tests live in `spec/integration/`
- Use existing WSDL fixtures in `spec/fixtures/` (45+ real-world documents)
- Add new fixtures when testing WSDL features not covered by existing ones
- Every public method must be tested; the project targets 100% code coverage

## Documentation

- All public methods require complete YARD docs (description, `@param`, `@return`)
- Use proper YARD type syntax: `Hash{String => String}` not `Hash<String, String>`
- Detailed guides live in the `docs/` folder; keep the README brief

## Getting Help

Not sure where to start? Open an [issue](https://github.com/rubiii/wsdl/issues) and ask.
We're happy to point you in the right direction.
