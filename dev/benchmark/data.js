window.BENCHMARK_DATA = {
  "lastUpdate": 1774734708557,
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
          "id": "52790ffb269352d23940195bec922093a55324be",
          "message": "Mark Operation#input_style and #output_style as private API\n\nDirect users to contract.style for public introspection. Marking these\nas @api private before 1.0 avoids locking them into the public API\nsurface under semver.",
          "timestamp": "2026-03-06T19:16:25+01:00",
          "tree_id": "f99a599910a1ad6c99d1b7034f6daa352dd4230a",
          "url": "https://github.com/rubiii/wsdl/commit/52790ffb269352d23940195bec922093a55324be"
        },
        "date": 1772821093446,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1962.65,
            "unit": "i/s",
            "range": "± 2.5%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.33,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4427.71,
            "unit": "i/s",
            "range": "± 0.6%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 683.04,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 653.27,
            "unit": "i/s",
            "range": "± 2.4%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10021.5,
            "unit": "i/s",
            "range": "± 1.0%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 120.95,
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
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "ee97337a46aa7a8e7d0d0398981517f7dd4a444a",
          "message": "Add Contributor Covenant Code of Conduct",
          "timestamp": "2026-03-06T19:19:34+01:00",
          "tree_id": "01d012c430f8d6d7bbe45a3bb24b497c1e3b2d8c",
          "url": "https://github.com/rubiii/wsdl/commit/ee97337a46aa7a8e7d0d0398981517f7dd4a444a"
        },
        "date": 1772821250947,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1845.58,
            "unit": "i/s",
            "range": "± 4.9%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.05,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4276.78,
            "unit": "i/s",
            "range": "± 1.9%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 659.57,
            "unit": "i/s",
            "range": "± 2.4%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 633.92,
            "unit": "i/s",
            "range": "± 3.5%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9356.29,
            "unit": "i/s",
            "range": "± 2.1%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 118,
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
          "id": "dedb26d34ab69f1fbafb8d8b45419f72723c34ef",
          "message": "Add CONTRIBUTING.md",
          "timestamp": "2026-03-06T19:39:02+01:00",
          "tree_id": "d514dc46d335557ce9ba590ca09afbc2e8600d3b",
          "url": "https://github.com/rubiii/wsdl/commit/dedb26d34ab69f1fbafb8d8b45419f72723c34ef"
        },
        "date": 1772822411655,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 2014.01,
            "unit": "i/s",
            "range": "± 2.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.38,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4488.24,
            "unit": "i/s",
            "range": "± 0.5%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 696,
            "unit": "i/s",
            "range": "± 1.3%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 686.98,
            "unit": "i/s",
            "range": "± 1.7%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10188.31,
            "unit": "i/s",
            "range": "± 0.9%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 124.13,
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
          "id": "b270bfdeb3ad0f60fdccad1abfb81e31b7fb0c4f",
          "message": "Add SECURITY.md",
          "timestamp": "2026-03-06T19:54:38+01:00",
          "tree_id": "bef2812f46a57942230de5275d8f978d0304b0b7",
          "url": "https://github.com/rubiii/wsdl/commit/b270bfdeb3ad0f60fdccad1abfb81e31b7fb0c4f"
        },
        "date": 1772823355020,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1940.6,
            "unit": "i/s",
            "range": "± 3.2%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.09,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4324.01,
            "unit": "i/s",
            "range": "± 2.5%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 676.39,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 644.35,
            "unit": "i/s",
            "range": "± 2.2%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9403.25,
            "unit": "i/s",
            "range": "± 2.8%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 116.36,
            "unit": "i/s",
            "range": "± 2.6%"
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
          "id": "b77ed6a79b0da2748865c2fbd5c92c54c9523a8b",
          "message": "Add pr and issue templates",
          "timestamp": "2026-03-06T20:00:48+01:00",
          "tree_id": "4bf127a162310c3e7fbb88f44b2094e967fc8099",
          "url": "https://github.com/rubiii/wsdl/commit/b77ed6a79b0da2748865c2fbd5c92c54c9523a8b"
        },
        "date": 1772823790085,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1744.95,
            "unit": "i/s",
            "range": "± 6.1%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.15,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4455.17,
            "unit": "i/s",
            "range": "± 1.4%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 662.16,
            "unit": "i/s",
            "range": "± 5.4%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 643.9,
            "unit": "i/s",
            "range": "± 3.1%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9725.36,
            "unit": "i/s",
            "range": "± 4.7%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 119.42,
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
          "id": "a715f6d055365b507b25f06de40e663e4dc19341",
          "message": "Require nokogiri >= 1.19.1\n\n1.19.1 is an important security release.",
          "timestamp": "2026-03-06T20:34:10+01:00",
          "tree_id": "205b2759fa92568038e1d3d5d56af11df459f8c9",
          "url": "https://github.com/rubiii/wsdl/commit/a715f6d055365b507b25f06de40e663e4dc19341"
        },
        "date": 1772825908227,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1965.12,
            "unit": "i/s",
            "range": "± 1.9%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.28,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4405.5,
            "unit": "i/s",
            "range": "± 1.2%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 686.54,
            "unit": "i/s",
            "range": "± 2.0%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 658.78,
            "unit": "i/s",
            "range": "± 4.9%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10054.31,
            "unit": "i/s",
            "range": "± 2.9%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 120.96,
            "unit": "i/s",
            "range": "± 2.5%"
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
          "id": "39f3e5216176bfe71b279cce98f6c7172c51f991",
          "message": "Prepare for 1.0 release",
          "timestamp": "2026-03-06T21:43:12+01:00",
          "tree_id": "e9b3a9ddd3a242d0b4956aefab481b34d8ef6e7b",
          "url": "https://github.com/rubiii/wsdl/commit/39f3e5216176bfe71b279cce98f6c7172c51f991"
        },
        "date": 1772829867188,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1893.22,
            "unit": "i/s",
            "range": "± 3.1%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 4.95,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 3943.93,
            "unit": "i/s",
            "range": "± 3.0%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 670.28,
            "unit": "i/s",
            "range": "± 3.0%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 646.06,
            "unit": "i/s",
            "range": "± 3.6%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9136.34,
            "unit": "i/s",
            "range": "± 1.4%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 110.73,
            "unit": "i/s",
            "range": "± 1.8%"
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
          "id": "c4d5123c12c550ea88255eab0ee8f8295e7fe1bd",
          "message": "Add mutant gem for mutation testing\n\n* Run on security module:\n  bundle exec mutant run 'WSDL::Security*'\n* Run on a single class:\n  bundle exec mutant run 'WSDL::Security::Signature'",
          "timestamp": "2026-03-08T17:19:00+01:00",
          "tree_id": "3fdf4b993461988e351b9fa9894fa16b57bed39d",
          "url": "https://github.com/rubiii/wsdl/commit/c4d5123c12c550ea88255eab0ee8f8295e7fe1bd"
        },
        "date": 1772993257130,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1952.74,
            "unit": "i/s",
            "range": "± 1.7%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.16,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4509.46,
            "unit": "i/s",
            "range": "± 0.7%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 687.58,
            "unit": "i/s",
            "range": "± 2.6%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 672.05,
            "unit": "i/s",
            "range": "± 3.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10165.48,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 120.45,
            "unit": "i/s",
            "range": "± 2.5%"
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
          "id": "eb008d08c54ba202aeb9793aa97811970699dcab",
          "message": "Remove dead .delete(\":\") call from SKI validation\n\nRemove dead .delete(\":\") call from SKI validation.\nThe SKI value was only nil-checked, never used as a string.",
          "timestamp": "2026-03-21T10:45:20+01:00",
          "tree_id": "9b4a02d306df328454c525c32fd65f45874505a3",
          "url": "https://github.com/rubiii/wsdl/commit/eb008d08c54ba202aeb9793aa97811970699dcab"
        },
        "date": 1774086500775,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1933.03,
            "unit": "i/s",
            "range": "± 2.1%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.07,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 4374.15,
            "unit": "i/s",
            "range": "± 2.3%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 672.72,
            "unit": "i/s",
            "range": "± 2.2%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 644.03,
            "unit": "i/s",
            "range": "± 3.9%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9762.46,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 115.49,
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
          "id": "4f6a09ff8db64cabd32975d4eb0cb1fef3c255b1",
          "message": "Mark PartContract#elements as @api private\n\nAlso migrated tests that accessed raw Element objects\nto use the public paths API instead.",
          "timestamp": "2026-03-23T16:09:03+01:00",
          "tree_id": "914fbd0e1a4a08ae77de06235672f42c1959cb88",
          "url": "https://github.com/rubiii/wsdl/commit/4f6a09ff8db64cabd32975d4eb0cb1fef3c255b1"
        },
        "date": 1774278665493,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1949.76,
            "unit": "i/s",
            "range": "± 2.5%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 5.17,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 3722.46,
            "unit": "i/s",
            "range": "± 0.7%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 690.07,
            "unit": "i/s",
            "range": "± 1.7%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 669.55,
            "unit": "i/s",
            "range": "± 3.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8491.89,
            "unit": "i/s",
            "range": "± 0.6%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 97.21,
            "unit": "i/s",
            "range": "± 1.0%"
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
          "id": "b412cc1700e2119dfbfd5674b80787b2cb2a8d56",
          "message": "Fix benchmark script",
          "timestamp": "2026-03-26T16:44:41+01:00",
          "tree_id": "805c7c51eaef2d03d8253ddf73610c56473b955b",
          "url": "https://github.com/rubiii/wsdl/commit/b412cc1700e2119dfbfd5674b80787b2cb2a8d56"
        },
        "date": 1774539955001,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 637.65,
            "unit": "i/s",
            "range": "± 20.9%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 0.86,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 11898.9,
            "unit": "i/s",
            "range": "± 1.9%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 677.7,
            "unit": "i/s",
            "range": "± 1.5%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 685.37,
            "unit": "i/s",
            "range": "± 3.9%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 10187.63,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 93.62,
            "unit": "i/s",
            "range": "± 2.1%"
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
          "id": "3fd722d66d8612bb0e3ccdfc839fd3662c4dafd1",
          "message": "Delegate Schema::Node attributes to Nokogiri directly\n\nRemove the eager @attributes_hash that materialized all XML attributes\ninto a Ruby Hash on every Node construction. All attribute accessors now\ndelegate to Nokogiri's C-level Node#[] lookup which returns the same\nString values without the intermediate Hash + Attr object allocations.",
          "timestamp": "2026-03-27T15:19:52+01:00",
          "tree_id": "917d42f26e5c67325901617632f39e5b72d148c5",
          "url": "https://github.com/rubiii/wsdl/commit/3fd722d66d8612bb0e3ccdfc839fd3662c4dafd1"
        },
        "date": 1774621559340,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 905.1,
            "unit": "i/s",
            "range": "± 13.4%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.28,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 8770.01,
            "unit": "i/s",
            "range": "± 6.7%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 632.99,
            "unit": "i/s",
            "range": "± 10.6%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 625.91,
            "unit": "i/s",
            "range": "± 16.3%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8048.22,
            "unit": "i/s",
            "range": "± 8.4%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 88.6,
            "unit": "i/s",
            "range": "± 7.9%"
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
          "id": "429b96fc48d68c8464c8db7d5d5fa6827313a0b5",
          "message": "Cache Schema::Node attribute reads\n\nNokogiri allocates a new Ruby String for every Node#[] call.\nSchema::Node\naccessors (name, type, ref, base, etc.) delegate to Node#[] and are read\nmultiple times per node during element building — up to 6x for `type`.",
          "timestamp": "2026-03-27T20:06:31+01:00",
          "tree_id": "ab59d9f6fa50d4835913edebd3bcba2fd124c794",
          "url": "https://github.com/rubiii/wsdl/commit/429b96fc48d68c8464c8db7d5d5fa6827313a0b5"
        },
        "date": 1774638474075,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1013.62,
            "unit": "i/s",
            "range": "± 18.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.5,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 10396.3,
            "unit": "i/s",
            "range": "± 7.8%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 842.57,
            "unit": "i/s",
            "range": "± 16.0%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 623.27,
            "unit": "i/s",
            "range": "± 13.5%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8792.09,
            "unit": "i/s",
            "range": "± 9.8%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 86.72,
            "unit": "i/s",
            "range": "± 10.4%"
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
          "id": "11647da9d74e1293020d5d8618b970ffaa6545d0",
          "message": "Remove strict_schema",
          "timestamp": "2026-03-27T21:53:05+01:00",
          "tree_id": "c061a2c27dcc14263ce0fb8d5aa22299ef137c76",
          "url": "https://github.com/rubiii/wsdl/commit/11647da9d74e1293020d5d8618b970ffaa6545d0"
        },
        "date": 1774644882196,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 971.63,
            "unit": "i/s",
            "range": "± 13.9%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.52,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 9169.75,
            "unit": "i/s",
            "range": "± 6.7%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 655.3,
            "unit": "i/s",
            "range": "± 8.7%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 637.66,
            "unit": "i/s",
            "range": "± 10.8%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8612.2,
            "unit": "i/s",
            "range": "± 6.7%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 95.65,
            "unit": "i/s",
            "range": "± 9.4%"
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
          "id": "7f44a6a54776f1c15a0e8f5cc656026b3c95fc9f",
          "message": "Lower to still ok threshold for CI",
          "timestamp": "2026-03-27T21:57:03+01:00",
          "tree_id": "a3d2f38e2adfad0fe72c395cf41898802fd24127",
          "url": "https://github.com/rubiii/wsdl/commit/7f44a6a54776f1c15a0e8f5cc656026b3c95fc9f"
        },
        "date": 1774645505414,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 934.67,
            "unit": "i/s",
            "range": "± 14.7%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.5,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 9170.66,
            "unit": "i/s",
            "range": "± 7.2%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 646.43,
            "unit": "i/s",
            "range": "± 9.3%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 621.97,
            "unit": "i/s",
            "range": "± 11.9%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8294.57,
            "unit": "i/s",
            "range": "± 8.0%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 92.69,
            "unit": "i/s",
            "range": "± 8.6%"
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
          "id": "9e30c82087c65c74232f7349c09765fce3b3de12",
          "message": "Fix ThreatScanner allocation blowup on Ruby 3.3\n\nopen_tag_start? allocated a fresh Array on every `<` character.\nRuby 3.4 optimizes this away, but 3.3 does not. Replace with a\nfrozen Set constant matching the existing WHITESPACE_BYTES and\nQUOTE_BYTES pattern.",
          "timestamp": "2026-03-27T22:10:06+01:00",
          "tree_id": "7f29ead91def7025b24dbd1337ad95733c0f9c97",
          "url": "https://github.com/rubiii/wsdl/commit/9e30c82087c65c74232f7349c09765fce3b3de12"
        },
        "date": 1774645877066,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 999.21,
            "unit": "i/s",
            "range": "± 16.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.46,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 10262.46,
            "unit": "i/s",
            "range": "± 8.1%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 847.07,
            "unit": "i/s",
            "range": "± 14.8%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 611.73,
            "unit": "i/s",
            "range": "± 15.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8613.26,
            "unit": "i/s",
            "range": "± 8.6%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 83.03,
            "unit": "i/s",
            "range": "± 10.8%"
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
          "id": "4532f0ed073b864b3fbff575ea89288b12ac31b3",
          "message": "Extract build_single_operation and OperationInfo delegators\n\nRefactors the large build_operations loop into two focused methods\n(build_single_operation, populate_operation_metadata) and adds\ninput?, rpc_input_namespace, rpc_output_namespace delegators to\nOperationInfo so the builder goes through the facade instead of\nreaching into binding internals.\n\n* Add builder edge-case tests: missing portType op, missing input\n  element, overloaded operations, unresolved binding reference\n* Add OperationInfo spec covering the new delegator methods",
          "timestamp": "2026-03-28T15:21:45+01:00",
          "tree_id": "8e50a214e3b354b8a19a3e9eb182d0c6f833ea82",
          "url": "https://github.com/rubiii/wsdl/commit/4532f0ed073b864b3fbff575ea89288b12ac31b3"
        },
        "date": 1774707815363,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1014.12,
            "unit": "i/s",
            "range": "± 4.7%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.65,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 10935.22,
            "unit": "i/s",
            "range": "± 2.4%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 670.49,
            "unit": "i/s",
            "range": "± 1.5%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 690.79,
            "unit": "i/s",
            "range": "± 3.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9162.84,
            "unit": "i/s",
            "range": "± 2.4%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 78.38,
            "unit": "i/s",
            "range": "± 5.1%"
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
          "id": "da26d623e84a1575838de3e8c99d352c232958cc",
          "message": "Update changelog",
          "timestamp": "2026-03-28T15:49:50+01:00",
          "tree_id": "1fba7455f6256dd8cbbd38191973f3583d87fa6f",
          "url": "https://github.com/rubiii/wsdl/commit/da26d623e84a1575838de3e8c99d352c232958cc"
        },
        "date": 1774709468181,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 983.42,
            "unit": "i/s",
            "range": "± 4.0%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.54,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 9082.01,
            "unit": "i/s",
            "range": "± 3.1%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 668.39,
            "unit": "i/s",
            "range": "± 2.7%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 647.03,
            "unit": "i/s",
            "range": "± 3.1%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8106.74,
            "unit": "i/s",
            "range": "± 2.0%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 92.53,
            "unit": "i/s",
            "range": "± 1.1%"
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
          "id": "a29e75dc916591427f221dc9f50a9885c6155bf5",
          "message": "Allow upgrades to Nokogiri 1.20",
          "timestamp": "2026-03-28T15:58:25+01:00",
          "tree_id": "91eefc41d118f169a84d692ec8aee3a121216cd0",
          "url": "https://github.com/rubiii/wsdl/commit/a29e75dc916591427f221dc9f50a9885c6155bf5"
        },
        "date": 1774710013625,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 724.89,
            "unit": "i/s",
            "range": "± 12.8%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.3,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 7279.35,
            "unit": "i/s",
            "range": "± 3.1%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 526.72,
            "unit": "i/s",
            "range": "± 6.1%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 528.95,
            "unit": "i/s",
            "range": "± 5.5%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 6842.72,
            "unit": "i/s",
            "range": "± 4.9%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 66.03,
            "unit": "i/s",
            "range": "± 4.5%"
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
          "id": "e5d654c83a47f188e05defdc2b15a3e1411bc1ff",
          "message": "Document thread safety",
          "timestamp": "2026-03-28T19:43:28+01:00",
          "tree_id": "1d377a3cd987a6dfc34cefbfebddc02df5422d17",
          "url": "https://github.com/rubiii/wsdl/commit/e5d654c83a47f188e05defdc2b15a3e1411bc1ff"
        },
        "date": 1774723480210,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 982.72,
            "unit": "i/s",
            "range": "± 5.6%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.52,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 9403.04,
            "unit": "i/s",
            "range": "± 0.6%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 680.94,
            "unit": "i/s",
            "range": "± 1.8%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 683.08,
            "unit": "i/s",
            "range": "± 2.0%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8740.92,
            "unit": "i/s",
            "range": "± 0.8%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 97.93,
            "unit": "i/s",
            "range": "± 1.0%"
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
          "id": "62348b788a73929dbf46042e4163ad034604888e",
          "message": "Update changelog",
          "timestamp": "2026-03-28T20:32:50+01:00",
          "tree_id": "348944e094bfd372e82bcafa703b269a311981c8",
          "url": "https://github.com/rubiii/wsdl/commit/62348b788a73929dbf46042e4163ad034604888e"
        },
        "date": 1774726445432,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 982.04,
            "unit": "i/s",
            "range": "± 6.1%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.58,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 9048.59,
            "unit": "i/s",
            "range": "± 1.1%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 685.79,
            "unit": "i/s",
            "range": "± 1.6%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 682.33,
            "unit": "i/s",
            "range": "± 2.9%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 8208.98,
            "unit": "i/s",
            "range": "± 5.7%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 82.92,
            "unit": "i/s",
            "range": "± 4.8%"
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
          "id": "73b7d168ae24ef54ef9721d055a1b7946876f7ba",
          "message": "Release Nokogiri DOM references after Definition building\n\nAfter Definition::Builder extracts all data into the frozen IR,\nSchema::Node objects still hold @xml_node references that keep the\nentire Nokogiri DOM alive until Parser.parse returns. This adds\nrelease_dom_references! cascading through Collection → Definition →\nNode to nil out DOM references in the ensure block, allowing the GC\nto reclaim DOM trees while the schema collection is still on the stack.",
          "timestamp": "2026-03-28T21:47:28+01:00",
          "tree_id": "61665c6bf91b0c270eb073bd9f985438863b1844",
          "url": "https://github.com/rubiii/wsdl/commit/73b7d168ae24ef54ef9721d055a1b7946876f7ba"
        },
        "date": 1774731308812,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 1065.06,
            "unit": "i/s",
            "range": "± 4.9%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.69,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 10393.15,
            "unit": "i/s",
            "range": "± 0.4%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 956.74,
            "unit": "i/s",
            "range": "± 1.7%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 659.1,
            "unit": "i/s",
            "range": "± 2.6%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 9149.22,
            "unit": "i/s",
            "range": "± 0.7%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 91.88,
            "unit": "i/s",
            "range": "± 1.1%"
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
          "id": "8287790fc138b5dbab574416adc44a0c5a817cbe",
          "message": "Fix Verifier#valid? returning stale timestamp results\n\nCrypto verification (phases 1-5) is deterministic for a given\ndocument and is now cached after the first evaluation. Timestamp\nfreshness (phase 6) is time-dependent and is re-evaluated on every\ncall so that a Verifier held across a time boundary correctly\ndetects expiration.",
          "timestamp": "2026-03-28T22:42:46+01:00",
          "tree_id": "b09987d47b9725eec218fcffbc76a7a84deecbcd",
          "url": "https://github.com/rubiii/wsdl/commit/8287790fc138b5dbab574416adc44a0c5a817cbe"
        },
        "date": 1774734707653,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "parse: small WSDL (blz_service, 88 lines)",
            "value": 921.62,
            "unit": "i/s",
            "range": "± 6.8%"
          },
          {
            "name": "parse: large WSDL (economic, 65k lines)",
            "value": 1.44,
            "unit": "i/s",
            "range": "± 0.0%"
          },
          {
            "name": "request: build + serialize",
            "value": 8568.02,
            "unit": "i/s",
            "range": "± 2.8%"
          },
          {
            "name": "sign: X.509 SHA-256 + Timestamp",
            "value": 648.1,
            "unit": "i/s",
            "range": "± 2.0%"
          },
          {
            "name": "verify: signature + timestamp",
            "value": 638.89,
            "unit": "i/s",
            "range": "± 3.6%"
          },
          {
            "name": "response: parse small (15 lines)",
            "value": 7732.73,
            "unit": "i/s",
            "range": "± 2.5%"
          },
          {
            "name": "response: parse large (200 items)",
            "value": 84.38,
            "unit": "i/s",
            "range": "± 3.6%"
          }
        ]
      }
    ]
  }
}