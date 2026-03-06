window.BENCHMARK_DATA = {
  "lastUpdate": 1772799757048,
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
      },
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
          "id": "f9fc051796d5c8d9ee7e5e67b06c10f12b195206",
          "message": "Add yard audit to Rake ci task",
          "timestamp": "2026-03-06T13:16:59+01:00",
          "tree_id": "8ba45e17941d88013265003678d8da614e8926d3",
          "url": "https://github.com/rubiii/wsdl/commit/f9fc051796d5c8d9ee7e5e67b06c10f12b195206"
        },
        "date": 1772799493739,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1431.34,
            "unit": "i/s",
            "range": "± 2.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 3.16,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4511.41,
            "unit": "i/s",
            "range": "± 1.4%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 680.54,
            "unit": "i/s",
            "range": "± 1.9%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 677.21,
            "unit": "i/s",
            "range": "± 4.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10148.81,
            "unit": "i/s",
            "range": "± 2.9%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 118.94,
            "unit": "i/s",
            "range": "± 0.8%"
          }
        ]
      },
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
          "id": "2d99314445621f0fb902f5eab203558896aa8418",
          "message": "Add yard audit to GitHub ci task",
          "timestamp": "2026-03-06T13:21:25+01:00",
          "tree_id": "3884e7e470396ed92cdb8d44febfa906dd9a9c12",
          "url": "https://github.com/rubiii/wsdl/commit/2d99314445621f0fb902f5eab203558896aa8418"
        },
        "date": 1772799756320,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1434.55,
            "unit": "i/s",
            "range": "± 2.4%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 3.19,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4391.34,
            "unit": "i/s",
            "range": "± 2.2%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 693.13,
            "unit": "i/s",
            "range": "± 1.7%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 677.39,
            "unit": "i/s",
            "range": "± 4.1%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9892.2,
            "unit": "i/s",
            "range": "± 5.0%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 119,
            "unit": "i/s",
            "range": "± 3.4%"
          }
        ]
      }
    ]
  }
}