window.BENCHMARK_DATA = {
  "lastUpdate": 1774278665955,
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
      }
    ]
  }
}