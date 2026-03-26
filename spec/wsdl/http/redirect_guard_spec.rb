# frozen_string_literal: true

RSpec.describe WSDL::HTTP::RedirectGuard do
  # Lightweight host class to test the module in isolation,
  # independent of HTTP::Client's other concerns.
  let(:guard) { Class.new { include WSDL::HTTP::RedirectGuard }.new }

  describe 'PRIVATE_IP_RANGES' do
    subject(:ranges) { described_class::PRIVATE_IP_RANGES }

    it 'is frozen' do
      expect(ranges).to be_frozen
    end

    it 'contains exactly 26 ranges' do
      expect(ranges.size).to eq(26)
    end

    [
      ['0.0.0.0/8',          'current network (RFC 1122)'],
      ['10.0.0.0/8',         'private (RFC 1918)'],
      ['100.64.0.0/10',      'shared address space (RFC 6598)'],
      ['127.0.0.0/8',        'loopback (RFC 1122)'],
      ['169.254.0.0/16',     'link-local (RFC 3927)'],
      ['172.16.0.0/12',      'private (RFC 1918)'],
      ['192.0.0.0/24',       'IETF protocol assignments (RFC 6890)'],
      ['192.0.2.0/24',       'documentation TEST-NET-1 (RFC 5737)'],
      ['192.88.99.0/24',     '6to4 relay anycast (RFC 7526)'],
      ['192.168.0.0/16',     'private (RFC 1918)'],
      ['198.18.0.0/15',      'benchmarking (RFC 2544)'],
      ['198.51.100.0/24',    'documentation TEST-NET-2 (RFC 5737)'],
      ['203.0.113.0/24',     'documentation TEST-NET-3 (RFC 5737)'],
      ['240.0.0.0/4',        'reserved for future use (RFC 1112)'],
      ['255.255.255.255/32', 'broadcast'],
      ['::/128',             'IPv6 unspecified (RFC 4291)'],
      ['::1/128',            'IPv6 loopback'],
      ['64:ff9b::/96',       'NAT64 well-known prefix (RFC 6052)'],
      ['64:ff9b:1::/48',     'NAT64 local-use prefix (RFC 8215)'],
      ['100::/64',           'discard-only prefix (RFC 6666)'],
      ['2001::/32',          'Teredo tunneling (RFC 4380)'],
      ['2001:10::/28',       'ORCHID addresses (RFC 4843)'],
      ['2001:db8::/32',      'IPv6 documentation (RFC 3849)'],
      ['2002::/16',          '6to4 addresses (RFC 3056)'],
      ['fc00::/7',           'IPv6 unique local (RFC 4193)'],
      ['fe80::/10',          'IPv6 link-local']
    ].each do |cidr, label|
      it "includes #{cidr} (#{label})" do
        expect(ranges).to include(IPAddr.new(cidr))
      end
    end
  end

  describe 'DNS_RESOLUTION_TIMEOUT' do
    it 'is 5 seconds' do
      expect(described_class::DNS_RESOLUTION_TIMEOUT).to eq(5)
    end
  end

  describe 'SENSITIVE_HEADERS' do
    subject(:headers) { described_class::SENSITIVE_HEADERS }

    it 'is frozen' do
      expect(headers).to be_frozen
    end

    it 'contains authorization, cookie, and proxy-authorization' do
      expect(headers).to contain_exactly('authorization', 'cookie', 'proxy-authorization')
    end
  end

  describe '#cross_origin?' do
    it 'returns false for same host and scheme' do
      a = URI.parse('https://example.com/path')
      b = URI.parse('https://example.com/other')

      expect(guard.send(:cross_origin?, a, b)).to be false
    end

    it 'returns true for different hosts' do
      a = URI.parse('https://example.com/path')
      b = URI.parse('https://other.example.com/path')

      expect(guard.send(:cross_origin?, a, b)).to be true
    end

    it 'returns false for http to https upgrade on same host' do
      a = URI.parse('http://example.com/path')
      b = URI.parse('https://example.com/path')

      expect(guard.send(:cross_origin?, a, b)).to be false
    end

    it 'returns true for explicit non-default port' do
      a = URI.parse('https://example.com/path')
      b = URI.parse('https://example.com:8443/path')

      expect(guard.send(:cross_origin?, a, b)).to be true
    end

    it 'returns false for explicit default port vs implicit default port' do
      a = URI.parse('https://example.com/path')
      b = URI.parse('https://example.com:443/path')

      expect(guard.send(:cross_origin?, a, b)).to be false
    end

    it 'returns true for same explicit non-default port on different hosts' do
      a = URI.parse('https://example.com:8443/path')
      b = URI.parse('https://other.example.com:8443/path')

      expect(guard.send(:cross_origin?, a, b)).to be true
    end

    it 'returns true for different explicit non-default ports on same host' do
      a = URI.parse('http://example.com:8080/path')
      b = URI.parse('http://example.com:9090/path')

      expect(guard.send(:cross_origin?, a, b)).to be true
    end

    it 'is case-insensitive for host comparison' do
      a = URI.parse('https://Example.COM/path')
      b = URI.parse('https://example.com/path')

      expect(guard.send(:cross_origin?, a, b)).to be false
    end
  end

  describe '#validate_redirect_scheme!' do
    it 'blocks HTTPS to HTTP downgrades' do
      original = URI.parse('https://example.com/service')
      target = URI.parse('http://example.com/service')

      expect { guard.send(:validate_redirect_scheme!, original, target) }
        .to raise_error(WSDL::UnsafeRedirectError, /HTTPS to HTTP downgrade/)
    end

    it 'includes both URIs in the error message' do
      original = URI.parse('https://a.example.com/svc')
      target = URI.parse('http://b.example.com/svc')

      expect { guard.send(:validate_redirect_scheme!, original, target) }
        .to raise_error(WSDL::UnsafeRedirectError,
          /from #{Regexp.escape(original.to_s)} to #{Regexp.escape(target.to_s)}/)
    end

    it 'stores the target URL on the error' do
      original = URI.parse('https://example.com/service')
      target = URI.parse('http://example.com/service')

      expect { guard.send(:validate_redirect_scheme!, original, target) }
        .to raise_error(WSDL::UnsafeRedirectError) { |error|
          expect(error.target_url).to eq(target.to_s)
        }
    end

    it 'allows HTTP to HTTP redirects' do
      original = URI.parse('http://example.com/service')
      target = URI.parse('http://other.example.com/service')

      expect { guard.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
    end

    it 'allows HTTPS to HTTPS redirects' do
      original = URI.parse('https://example.com/service')
      target = URI.parse('https://other.example.com/service')

      expect { guard.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
    end

    it 'allows HTTP to HTTPS upgrades' do
      original = URI.parse('http://example.com/service')
      target = URI.parse('https://example.com/service')

      expect { guard.send(:validate_redirect_scheme!, original, target) }.not_to raise_error
    end

    context 'with non-HTTP schemes' do
      %w[file ftp gopher data ldap].each do |scheme|
        it "blocks #{scheme}:// redirects" do
          original = URI.parse('https://example.com/service')
          target = URI.parse("#{scheme}://example.com/path")

          expect { guard.send(:validate_redirect_scheme!, original, target) }
            .to raise_error(WSDL::UnsafeRedirectError, /non-HTTP scheme '#{scheme}'/)
        end
      end

      it 'stores the target URL on the error' do
        original = URI.parse('https://example.com/service')
        target = URI.parse('file:///etc/passwd')

        expect { guard.send(:validate_redirect_scheme!, original, target) }
          .to raise_error(WSDL::UnsafeRedirectError) { |error|
            expect(error.target_url).to eq('file:///etc/passwd')
          }
      end

      # NOTE: In practice, resolve_redirect_uri resolves relative paths against
      # the original URI before this method is called, so nil schemes don't
      # reach here through request_with_redirects. This test documents the
      # method's standalone behavior for defense-in-depth.
      it 'blocks URIs with nil scheme as a defense-in-depth measure' do
        original = URI.parse('https://example.com/service')
        target = URI.parse('/relative/path')

        expect { guard.send(:validate_redirect_scheme!, original, target) }
          .to raise_error(WSDL::UnsafeRedirectError, /non-HTTP scheme/)
      end
    end
  end

  describe '#validate_redirect_target!' do
    context 'with private/reserved IPv4 address literals' do
      {
        '127.0.0.1' => 'loopback',
        '10.0.0.1' => 'RFC 1918 class A',
        '172.16.0.1' => 'RFC 1918 class B',
        '192.168.1.1' => 'RFC 1918 class C',
        '169.254.169.254' => 'link-local / cloud metadata',
        '100.64.0.1' => 'shared address space (RFC 6598)',
        '0.0.0.1' => 'current network (RFC 1122)',
        '192.0.0.1' => 'IETF protocol assignments (RFC 6890)',
        '192.0.2.1' => 'documentation TEST-NET-1 (RFC 5737)',
        '192.88.99.1' => '6to4 relay anycast (RFC 7526)',
        '198.18.0.1' => 'benchmarking (RFC 2544)',
        '198.51.100.1' => 'documentation TEST-NET-2 (RFC 5737)',
        '203.0.113.1' => 'documentation TEST-NET-3 (RFC 5737)',
        '240.0.0.1' => 'reserved for future use (RFC 1112)',
        '255.255.255.255' => 'broadcast'
      }.each do |ip, label|
        it "blocks #{ip} (#{label})" do
          uri = URI.parse("http://#{ip}/internal")

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    context 'with private IPv6 address literals' do
      {
        '::' => 'unspecified (RFC 4291)',
        '::1' => 'loopback',
        '64:ff9b::10.0.0.1' => 'NAT64 embedding private IPv4 (RFC 6052)',
        '64:ff9b::8.8.8.8' => 'NAT64 embedding public IPv4 (RFC 6052)',
        '64:ff9b:1::1' => 'NAT64 local-use prefix (RFC 8215)',
        '100::1' => 'discard-only prefix (RFC 6666)',
        '2001::1' => 'Teredo tunneling (RFC 4380)',
        '2001:10::1' => 'ORCHID (RFC 4843)',
        '2001:db8::1' => 'documentation (RFC 3849)',
        '2002:c0a8:0101::' => '6to4 encoding 192.168.1.1 (RFC 3056)',
        '2002:7f00:0001::' => '6to4 encoding 127.0.0.1 (RFC 3056)',
        'fc00::1' => 'unique local (RFC 4193)',
        'fe80::1' => 'link-local'
      }.each do |ip, label|
        it "blocks [#{ip}] (#{label})" do
          uri = URI.parse("http://[#{ip}]/internal")

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    context 'with IPv4-mapped IPv6 addresses' do
      # An attacker can represent any IPv4 address as ::ffff:<IPv4>.
      # Without normalization, these bypass IPv4 range checks because
      # IPAddr treats them as IPv6, not matching any IPv4 range.
      {
        '::ffff:127.0.0.1' => 'mapped loopback',
        '::ffff:10.0.0.1' => 'mapped RFC 1918',
        '::ffff:169.254.169.254' => 'mapped cloud metadata',
        '::ffff:192.168.1.1' => 'mapped RFC 1918 class C',
        '::ffff:172.16.0.1' => 'mapped RFC 1918 class B'
      }.each do |ip, label|
        it "blocks #{ip} (#{label})" do
          # Ruby's URI.parse rejects IPv4-mapped IPv6, so we stub hostname
          # to simulate a malicious redirect Location header.
          uri = instance_double(URI::HTTP, hostname: ip, host: ip, to_s: "http://[#{ip}]/")

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    context 'with IPv4-compatible IPv6 addresses' do
      # The deprecated ::x.x.x.x form (RFC 4291) is distinct from ::ffff:x.x.x.x.
      # IPAddr#ipv4_mapped? returns false for these, so without ipv4_compat?
      # normalization they would bypass all IPv4 range checks.
      {
        '::127.0.0.1' => 'compat loopback',
        '::10.0.0.1' => 'compat RFC 1918',
        '::169.254.169.254' => 'compat cloud metadata'
      }.each do |ip, label|
        it "blocks #{ip} (#{label})" do
          uri = instance_double(URI::HTTP, hostname: ip, host: ip, to_s: "http://[#{ip}]/")

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    context 'with IPv6 zone IDs' do
      # Zone IDs (e.g., fe80::1%eth0) cause IPAddr::InvalidAddressError
      # without stripping, which would bypass private IP detection.
      {
        'fe80::1%eth0' => 'link-local',
        '::1%lo' => 'loopback',
        'fc00::1%eth0' => 'unique local'
      }.each do |address, label|
        it "blocks #{label} with zone ID (#{address})" do
          uri = instance_double(URI::HTTP, hostname: address, host: address, to_s: "http://[#{address}]/")

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
        end
      end
    end

    context 'with public IP addresses' do
      %w[8.8.8.8 93.184.216.34 151.101.1.57].each do |ip|
        it "allows #{ip} and returns it for connection pinning" do
          uri = URI.parse("https://#{ip}/service")

          expect(guard.send(:validate_redirect_target!, uri)).to eq(ip)
        end
      end

      it 'allows a public IPv6 address' do
        uri = URI.parse('https://[2607:f8b0:4004:800::200e]/service')

        expect(guard.send(:validate_redirect_target!, uri)).to eq('2607:f8b0:4004:800::200e')
      end

      it 'normalizes IPv4-mapped IPv6 to native IPv4 for connection pinning' do
        uri = instance_double(URI::HTTP, hostname: '::ffff:93.184.216.34', host: '::ffff:93.184.216.34',
          to_s: 'http://[::ffff:93.184.216.34]/')

        expect(guard.send(:validate_redirect_target!, uri)).to eq('93.184.216.34')
      end
    end

    context 'with nil or empty host' do
      it 'returns nil for URI with nil host' do
        uri = instance_double(URI::HTTP, hostname: nil, host: nil)

        expect(guard.send(:validate_redirect_target!, uri)).to be_nil
      end

      it 'returns nil for URI with empty host' do
        uri = instance_double(URI::HTTP, hostname: '', host: '')

        expect(guard.send(:validate_redirect_target!, uri)).to be_nil
      end
    end

    context 'with range boundaries' do
      {
        # 172.16.0.0/12
        '172.15.255.255' => true,
        '172.16.0.0' => false,
        '172.31.255.255' => false,
        '172.32.0.0' => true,
        # 100.64.0.0/10
        '100.63.255.255' => true,
        '100.64.0.0' => false,
        '100.127.255.255' => false,
        '100.128.0.0' => true,
        # 192.88.99.0/24
        '192.88.98.255' => true,
        '192.88.99.0' => false,
        '192.88.99.255' => false,
        '192.88.100.0' => true,
        # 198.18.0.0/15
        '198.17.255.255' => true,
        '198.18.0.0' => false,
        '198.19.255.255' => false,
        '198.20.0.0' => true,
        # 203.0.113.0/24
        '203.0.112.255' => true,
        '203.0.113.0' => false,
        '203.0.113.255' => false,
        '203.0.114.0' => true,
        # 240.0.0.0/4
        '239.255.255.255' => true,
        '240.0.0.0' => false
      }.each do |ip, should_allow|
        if should_allow
          it "allows #{ip} (just outside blocked range)" do
            uri = URI.parse("https://#{ip}/service")

            expect { guard.send(:validate_redirect_target!, uri) }.not_to raise_error
          end
        else
          it "blocks #{ip} (inside blocked range)" do
            uri = URI.parse("http://#{ip}/service")

            expect { guard.send(:validate_redirect_target!, uri) }
              .to raise_error(WSDL::UnsafeRedirectError)
          end
        end
      end
    end

    context 'with IPv6 range boundaries' do
      {
        # 64:ff9b::/96 (NAT64)
        '64:ff9b::' => false,
        '64:ff9b::ffff:ffff' => false,
        '64:ff9c::' => true,
        # 64:ff9b:1::/48 (NAT64 local-use)
        '64:ff9b:1::' => false,
        '64:ff9b:1:ffff:ffff:ffff:ffff:ffff' => false,
        '64:ff9b:2::' => true,
        # 100::/64 (discard-only)
        '100::' => false,
        '100::ffff:ffff:ffff:ffff' => false,
        '100:0:0:1::' => true,
        # 2001::/32 (Teredo)
        '2001::' => false,
        '2001:0:ffff:ffff:ffff:ffff:ffff:ffff' => false,
        '2001:1::' => true,
        # 2001:10::/28 (ORCHID)
        '2001:10::' => false,
        '2001:1f:ffff:ffff:ffff:ffff:ffff:ffff' => false,
        '2001:20::' => true,
        # 2001:db8::/32 (documentation)
        '2001:db8::' => false,
        '2001:db8:ffff:ffff:ffff:ffff:ffff:ffff' => false,
        '2001:db9::' => true,
        # 2002::/16 (6to4)
        '2002::' => false,
        '2002:ffff:ffff:ffff:ffff:ffff:ffff:ffff' => false,
        '2003::' => true
      }.each do |ip, should_allow|
        if should_allow
          it "allows [#{ip}] (just outside blocked range)" do
            uri = URI.parse("https://[#{ip}]/service")

            expect { guard.send(:validate_redirect_target!, uri) }.not_to raise_error
          end
        else
          it "blocks [#{ip}] (inside blocked range)" do
            uri = URI.parse("http://[#{ip}]/internal")

            expect { guard.send(:validate_redirect_target!, uri) }
              .to raise_error(WSDL::UnsafeRedirectError)
          end
        end
      end
    end

    context 'with DNS resolution' do
      it 'blocks hostnames that resolve to private addresses' do
        uri = URI.parse('https://evil.example.com/internal')
        allow(Resolv).to receive(:getaddresses).with('evil.example.com').and_return(['127.0.0.1'])

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
      end

      it 'blocks when any resolved address is private (mixed results)' do
        uri = URI.parse('https://dual.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('dual.example.com').and_return(['93.184.216.34', '10.0.0.1'])

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError)
      end

      it 'blocks when DNS resolves to IPv4-mapped IPv6 private address' do
        uri = URI.parse('https://sneaky.example.com/internal')
        allow(Resolv).to receive(:getaddresses).with('sneaky.example.com').and_return(['::ffff:169.254.169.254'])

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError)
      end

      it 'allows hostnames that resolve to public addresses and returns the first for connection pinning' do
        uri = URI.parse('https://safe.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('safe.example.com').and_return(['93.184.216.34', '93.184.216.35'])

        expect(guard.send(:validate_redirect_target!, uri)).to eq('93.184.216.34')
      end

      it 'blocks when DNS resolution returns no addresses' do
        uri = URI.parse('https://empty.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('empty.example.com').and_return([])

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution returned no addresses/)
      end

      it 'blocks when DNS resolution times out' do
        uri = URI.parse('https://slow.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('slow.example.com') { raise Timeout::Error }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks when DNS resolution fails with ResolvError' do
        uri = URI.parse('https://nonexistent.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('nonexistent.example.com') { raise Resolv::ResolvError }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks when DNS resolution fails with SocketError' do
        uri = URI.parse('https://broken.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('broken.example.com') { raise SocketError }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks when DNS resolution fails with Errno::ECONNREFUSED' do
        uri = URI.parse('https://refused.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('refused.example.com') { raise Errno::ECONNREFUSED }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'blocks when DNS resolution fails with IOError' do
        uri = URI.parse('https://ioerror.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('ioerror.example.com') { raise IOError }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end

      it 'includes the target URL in DNS failure errors' do
        uri = URI.parse('https://timeout.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('timeout.example.com') { raise Timeout::Error }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError) { |error|
            expect(error.target_url).to eq('https://timeout.example.com/service')
          }
      end
    end

    context 'with alternative IP representations' do
      # IPAddr.new rejects these non-standard forms, so parse_ip returns nil
      # and they fall through to DNS resolution. Resolv.getaddresses then fails
      # because they are not valid hostnames. The redirect is blocked via DNS
      # failure rather than IP range matching — safe by design, not accident.
      {
        '0x7f000001' => 'hex for 127.0.0.1',
        '2130706433' => 'decimal for 127.0.0.1',
        '0177.0.0.1' => 'octal for 127.0.0.1',
        '127.1' => 'shorthand for 127.0.0.1'
      }.each do |ip, label|
        it "blocks #{ip} (#{label}) via DNS resolution failure" do
          uri = URI.parse("http://#{ip}/internal")
          allow(Resolv).to receive(:getaddresses).with(ip) { raise Resolv::ResolvError }

          expect { guard.send(:validate_redirect_target!, uri) }
            .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
        end
      end
    end

    context 'with double-URL-encoded hostnames' do
      # URI#hostname decodes one level of percent-encoding. A double-encoded
      # hostname like %2531%2532%2537 decodes to %31%32%37 (still encoded),
      # which IPAddr.new rejects. DNS resolution then fails because it is
      # not a valid hostname.
      it 'blocks double-encoded 127.0.0.1 via DNS resolution failure' do
        hostname = '%2531%2532%2537%252e%2530%252e%2530%252e%2531'
        uri = instance_double(URI::HTTP, hostname:, host: hostname, to_s: "http://#{hostname}/")
        allow(Resolv).to receive(:getaddresses).with(hostname) { raise Resolv::ResolvError }

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, /DNS resolution failed/)
      end
    end

    context 'with DNS resolving to a 6to4 address encoding a private IPv4' do
      it 'blocks 2002:c0a8:0101:: (encodes 192.168.1.1)' do
        uri = URI.parse('https://tricky.example.com/service')
        allow(Resolv).to receive(:getaddresses).with('tricky.example.com').and_return(['2002:c0a8:0101::'])

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError, %r{private/reserved address blocked})
      end
    end

    context 'with error attributes' do
      it 'includes the target URL in the error for IP literals' do
        uri = URI.parse('http://127.0.0.1/secret')

        expect { guard.send(:validate_redirect_target!, uri) }
          .to raise_error(WSDL::UnsafeRedirectError) { |error|
            expect(error.target_url).to eq('http://127.0.0.1/secret')
          }
      end
    end
  end
end
