# Contributing to WSDL

Thanks for your interest in contributing!

Please note that this project is released with a [Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to abide by its terms.

## Security Vulnerabilities

**Do not open a public issue for security vulnerabilities.** Instead, email
[security@rubiii.com](mailto:security@rubiii.com) with a description of the issue, steps to reproduce,
and any relevant WSDL fixtures. You will receive a response within 48 hours.

## Getting Started

Requirements: Ruby 3.3+ and Bundler.

```sh
git clone https://github.com/rubiii/wsdl.git
cd wsdl
bundle install
bundle exec rake ci   # Run all checks (Linting + Docs + Specs)
```

## How to Contribute

**Bug reports** — Open an [issue](https://github.com/rubiii/wsdl/issues) with a minimal WSDL fixture that reproduces the problem, the SOAP version, Ruby version, and steps to reproduce.

**Feature requests** — Open an issue to discuss the idea before writing code.

**Bug fixes** — Write a failing test, fix the bug, run `bundle exec rake ci`.

**Documentation** — Improvements to YARD docs, the `docs/` folder, or the README are welcome.

## Pull Requests

1. Fork the repository and create a branch from `main`
2. Keep each PR focused on a single concern
3. Include tests for any behavior changes
4. Ensure `bundle exec rake ci` passes
5. Write clear commit messages that explain *why*, not just *what*

For code style, naming conventions, and other guidelines, see the [development guide](docs/contributing/development.md). For testing details, see the [testing docs](docs/contributing/testing.md).

## Getting Help

Not sure where to start? Open an [issue](https://github.com/rubiii/wsdl/issues) and ask.
