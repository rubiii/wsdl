# Performance Benchmarks

## Overview

The project includes a benchmark suite that measures performance of critical operations using
[benchmark-ips](https://github.com/evanphx/benchmark-ips). Results are tracked over time via
[github-action-benchmark](https://github.com/benchmark-action/github-action-benchmark) and
published to GitHub Pages.

**Live dashboard:** <https://rubiii.github.io/wsdl/dev/benchmark/>

## What's Measured

The suite (`benchmarks/run.rb`) covers five areas:

| Benchmark | Description |
|-----------|-------------|
| **WSDL Parsing** | Parse a small (88 lines) and large (65k lines) WSDL document |
| **Request Building** | Build and serialize a SOAP request envelope |
| **WS-Security Signing** | Apply X.509 SHA-256 signature with timestamp |
| **WS-Security Verification** | Verify a signed envelope (signature + timestamp) |
| **Response Parsing** | Parse a small (15 lines) and large (200 items) SOAP response |

All benchmarks report iterations per second (i/s) — higher is better.

## Running Locally

```sh
bundle exec rake benchmark
```

To produce JSON output (CI format):

```sh
BENCHMARK_OUTPUT=benchmark_results.json bundle exec rake benchmark
```

## CI Integration

Benchmarks run automatically on every push to `main` and on pull requests (`.github/workflows/ci.yml`).

### How it works

1. The `benchmark` job runs `bundle exec rake benchmark` with `BENCHMARK_OUTPUT` set.
2. The [github-action-benchmark](https://github.com/benchmark-action/github-action-benchmark) action
   compares results against historical data stored on the `gh-pages` branch.
3. On `main`, results are automatically pushed to `gh-pages`, accumulating a historical record
   that powers the dashboard charts.
4. On pull requests, results are compared against the baseline but not pushed.

### Regression detection

- **Alert threshold:** 150% — a benchmark that drops to less than 2/3 of its previous value triggers an alert.
- **PR comments:** When a regression is detected, a comment is posted on the pull request.
- **CI failure:** The benchmark job fails when a regression exceeds the threshold, preventing merges.
