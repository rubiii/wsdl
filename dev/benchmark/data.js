window.BENCHMARK_DATA = {
  "lastUpdate": 1772796810279,
  "repoUrl": "https://github.com/rubiii/wsdl",
  "entries": {
    "Benchmark": [
      {
        "commit": {
          "author": {
            "email": "me@rubiii.com",
            "name": "rubiii",
            "username": "rubiii"
          },
          "committer": {
            "email": "me@rubiii.com",
            "name": "rubiii",
            "username": "rubiii"
          },
          "distinct": true,
          "id": "92cf427fe80c040a8ef6247780e9d7db97a3521a",
          "message": "Fix YARD compatibility with Ruby 4.0 by adding irb dependency",
          "timestamp": "2026-03-06T12:28:42+01:00",
          "tree_id": "f6adae00c5f0c5e01c114ef506f63c45186be620",
          "url": "https://github.com/rubiii/wsdl/commit/92cf427fe80c040a8ef6247780e9d7db97a3521a"
        },
        "date": 1772796809762,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1405.84,
            "unit": "i/s",
            "range": "± 4.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 3.1,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4334.66,
            "unit": "i/s",
            "range": "± 2.1%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 673.76,
            "unit": "i/s",
            "range": "± 1.5%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 647.59,
            "unit": "i/s",
            "range": "± 8.3%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9670.41,
            "unit": "i/s",
            "range": "± 2.2%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 118.65,
            "unit": "i/s",
            "range": "± 1.7%"
          }
        ]
      }
    ]
  }
}