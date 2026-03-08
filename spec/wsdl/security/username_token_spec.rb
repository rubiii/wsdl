# frozen_string_literal: true

RSpec.describe WSDL::Security::UsernameToken do
  let(:username) { 'testuser' }
  let(:password) { 'secret123' }

  describe '#initialize' do
    context 'with plain text mode (default)' do
      subject(:token) { described_class.new(username, password) }

      it 'stores the username' do
        expect(token.username).to eq(username)
      end

      it 'stores the password' do
        expect(token.password).to eq(password)
      end

      it 'sets digest to false' do
        expect(token.digest?).to be false
      end

      it 'does not generate a nonce' do
        expect(token.nonce).to be_nil
      end

      it 'sets created_at to current UTC time' do
        expect(token.created_at).to be_within(1).of(Time.now.utc)
      end

      it 'generates a unique ID' do
        expect(token.id).to start_with('UsernameToken-')
        expect(token.id).to match(/\AUsernameToken-[a-f0-9-]{36}\z/)
      end
    end

    context 'with digest mode' do
      subject(:token) { described_class.new(username, password, digest: true) }

      it 'sets digest to true' do
        expect(token.digest?).to be true
      end

      it 'generates a nonce' do
        expect(token.nonce).not_to be_nil
        expect(token.nonce.bytesize).to eq(16)
      end
    end

    context 'with custom created_at' do
      subject(:token) { described_class.new(username, password, created_at: custom_time) }

      let(:custom_time) { Time.utc(2026, 1, 15, 10, 30, 0) }

      it 'uses the provided created_at time' do
        expect(token.created_at).to eq(custom_time)
      end
    end

    context 'with custom id' do
      subject(:token) { described_class.new(username, password, id: 'custom-token-id') }

      it 'uses the provided ID' do
        expect(token.id).to eq('custom-token-id')
      end
    end
  end

  describe '#encoded_nonce' do
    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password) }

      it 'returns nil' do
        expect(token.encoded_nonce).to be_nil
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true) }

      it 'returns Base64-encoded nonce' do
        encoded = token.encoded_nonce
        expect(encoded).to be_a(String)

        # Verify it decodes back to 16 bytes
        decoded = Base64.strict_decode64(encoded)
        expect(decoded.bytesize).to eq(16)
      end

      it 'does not include newlines' do
        expect(token.encoded_nonce).not_to include("\n")
      end
    end
  end

  describe '#created_at_xml' do
    subject(:token) { described_class.new(username, password, created_at: time) }

    let(:time) { Time.utc(2026, 2, 1, 12, 30, 45) }

    it 'returns the created time in XML Schema dateTime format' do
      expect(token.created_at_xml).to eq('2026-02-01T12:30:45Z')
    end
  end

  describe '#password_value' do
    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password) }

      it 'returns the original password' do
        expect(token.password_value).to eq(password)
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true, created_at: time) }

      let(:time) { Time.utc(2026, 2, 1, 12, 0, 0) }

      it 'returns a Base64-encoded digest' do
        digest = token.password_value

        expect(digest).to be_a(String)
        expect(digest).not_to eq(password)
        expect(digest).not_to include("\n")
      end

      it 'computes digest as Base64(SHA1(nonce + created + password))' do
        nonce = token.nonce
        created = token.created_at_xml
        expected_token = nonce + created + password
        expected_digest = Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(expected_token))

        expect(token.password_value).to eq(expected_digest)
      end
    end
  end

  describe '#password_type' do
    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password) }

      it 'returns the PasswordText URI' do
        expect(token.password_type).to eq(WSDL::Security::Constants::TokenProfiles::UsernameToken::PASSWORD_TEXT)
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true) }

      it 'returns the PasswordDigest URI' do
        expect(token.password_type).to eq(WSDL::Security::Constants::TokenProfiles::UsernameToken::PASSWORD_DIGEST)
      end
    end
  end

  describe '#to_xml' do
    let(:time) { Time.utc(2026, 2, 1, 12, 0, 0) }

    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password, created_at: time, id: 'UT-plain-test') }

      it 'builds valid XML with Nokogiri builder' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.root(
            'xmlns:wsse' => WSDL::Security::Constants::NS::Security::WSSE,
            'xmlns:wsu' => WSDL::Security::Constants::NS::Security::WSU
          ) do
            token.to_xml(xml)
          end
        end

        doc = builder.doc
        ut_node = doc.at_xpath('//wsse:UsernameToken', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)

        expect(ut_node).not_to be_nil
        expect(ut_node['wsu:Id']).to eq('UT-plain-test')

        username_node = ut_node.at_xpath('wsse:Username', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)
        expect(username_node.text).to eq(username)

        password_node = ut_node.at_xpath('wsse:Password', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)
        expect(password_node.text).to eq(password)
        expect(password_node['Type']).to eq(WSDL::Security::Constants::TokenProfiles::UsernameToken::PASSWORD_TEXT)

        # Should not have Nonce or Created in plain text mode
        nonce_node = ut_node.at_xpath('wsse:Nonce', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)
        expect(nonce_node).to be_nil

        created_node = ut_node.at_xpath('wsu:Created', 'wsu' => WSDL::Security::Constants::NS::Security::WSU)
        expect(created_node).to be_nil
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true, created_at: time, id: 'UT-digest-test') }

      it 'builds valid XML with Nonce and Created elements' do
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.root(
            'xmlns:wsse' => WSDL::Security::Constants::NS::Security::WSSE,
            'xmlns:wsu' => WSDL::Security::Constants::NS::Security::WSU
          ) do
            token.to_xml(xml)
          end
        end

        doc = builder.doc
        ut_node = doc.at_xpath('//wsse:UsernameToken', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)

        expect(ut_node).not_to be_nil

        password_node = ut_node.at_xpath('wsse:Password', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)
        expect(password_node['Type']).to eq(WSDL::Security::Constants::TokenProfiles::UsernameToken::PASSWORD_DIGEST)
        expect(password_node.text).to eq(token.password_value)

        nonce_node = ut_node.at_xpath('wsse:Nonce', 'wsse' => WSDL::Security::Constants::NS::Security::WSSE)
        expect(nonce_node).not_to be_nil
        expect(nonce_node.text).to eq(token.encoded_nonce)
        expect(nonce_node['EncodingType']).to eq(WSDL::Security::Constants::Encoding::BASE64)

        created_node = ut_node.at_xpath('wsu:Created', 'wsu' => WSDL::Security::Constants::NS::Security::WSU)
        expect(created_node).not_to be_nil
        expect(created_node.text).to eq('2026-02-01T12:00:00Z')
      end
    end
  end

  describe '#to_hash' do
    let(:time) { Time.utc(2026, 2, 1, 12, 0, 0) }

    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password, created_at: time, id: 'UT-hash-plain') }

      it 'returns a hash with wsse:UsernameToken structure' do
        hash = token.to_hash

        expect(hash).to have_key('wsse:UsernameToken')
        expect(hash['wsse:UsernameToken']['wsse:Username']).to eq(username)
        expect(hash['wsse:UsernameToken']['wsse:Password']).to eq(password)
      end

      it 'includes the password Type attribute' do
        hash = token.to_hash

        expect(hash['wsse:UsernameToken'][:attributes!]['wsse:Password']).to eq(
          { 'Type' => WSDL::Security::Constants::TokenProfiles::UsernameToken::PASSWORD_TEXT }
        )
      end

      it 'specifies element order without Nonce and Created' do
        hash = token.to_hash

        expect(hash['wsse:UsernameToken'][:order!]).to eq(['wsse:Username', 'wsse:Password'])
      end

      it 'includes the wsu:Id attribute' do
        hash = token.to_hash

        expect(hash[:attributes!]).to eq(
          'wsse:UsernameToken' => { 'wsu:Id' => 'UT-hash-plain' }
        )
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true, created_at: time, id: 'UT-hash-digest') }

      it 'includes Nonce and Created in the hash' do
        hash = token.to_hash

        expect(hash['wsse:UsernameToken']['wsse:Nonce']).to eq(token.encoded_nonce)
        expect(hash['wsse:UsernameToken']['wsu:Created']).to eq('2026-02-01T12:00:00Z')
      end

      it 'includes Nonce EncodingType attribute' do
        hash = token.to_hash

        expect(hash['wsse:UsernameToken'][:attributes!]['wsse:Nonce']).to eq(
          { 'EncodingType' => WSDL::Security::Constants::Encoding::BASE64 }
        )
      end

      it 'specifies full element order' do
        hash = token.to_hash

        expect(hash['wsse:UsernameToken'][:order!]).to eq(
          ['wsse:Username', 'wsse:Password', 'wsse:Nonce', 'wsu:Created']
        )
      end
    end
  end

  describe 'unique IDs' do
    it 'generates different IDs for different instances' do
      token1 = described_class.new(username, password)
      token2 = described_class.new(username, password)

      expect(token1.id).not_to eq(token2.id)
    end
  end

  describe 'nonce uniqueness' do
    it 'generates different nonces for different instances' do
      token1 = described_class.new(username, password, digest: true)
      token2 = described_class.new(username, password, digest: true)

      expect(token1.nonce).not_to eq(token2.nonce)
    end
  end

  describe 'time zone handling' do
    it 'converts local time to UTC' do
      local_time = Time.new(2026, 2, 1, 12, 0, 0, '+05:00')
      token = described_class.new(username, password, created_at: local_time)

      # 12:00 +05:00 = 07:00 UTC
      expect(token.created_at).to eq(Time.utc(2026, 2, 1, 7, 0, 0))
      expect(token.created_at_xml).to eq('2026-02-01T07:00:00Z')
    end
  end

  describe 'digest consistency' do
    it 'produces consistent digest for same inputs' do
      time = Time.utc(2026, 2, 1, 12, 0, 0)

      # Create two tokens with same nonce (by stubbing)
      token1 = described_class.new(username, password, digest: true, created_at: time)

      # Manually compute expected digest
      expected_token = token1.nonce + time.xmlschema + password
      expected_digest = Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(expected_token))

      expect(token1.password_value).to eq(expected_digest)
    end
  end

  describe '#inspect' do
    context 'in plain text mode' do
      subject(:token) { described_class.new(username, password) }

      it 'includes the class name' do
        expect(token.inspect).to include('WSDL::Security::UsernameToken')
      end

      it 'includes the username' do
        expect(token.inspect).to include("username=#{username.inspect}")
      end

      it 'redacts the password' do
        expect(token.inspect).to include('password=[REDACTED]')
        expect(token.inspect).not_to include(password)
      end

      it 'includes the digest mode' do
        expect(token.inspect).to include('digest=false')
      end

      it 'does not include nonce (not present in plain text mode)' do
        expect(token.inspect).not_to include('nonce=')
      end
    end

    context 'in digest mode' do
      subject(:token) { described_class.new(username, password, digest: true) }

      it 'includes the class name' do
        expect(token.inspect).to include('WSDL::Security::UsernameToken')
      end

      it 'redacts the password' do
        expect(token.inspect).to include('password=[REDACTED]')
        expect(token.inspect).not_to include(password)
      end

      it 'includes the digest mode' do
        expect(token.inspect).to include('digest=true')
      end

      it 'redacts the nonce' do
        expect(token.inspect).to include('nonce=[REDACTED]')
        # Ensure the actual nonce bytes are not in the output
        expect(token.inspect).not_to include(token.nonce.inspect)
      end
    end

    context 'security scenarios' do
      subject(:token) { described_class.new(username, password, digest: true) }

      it 'is safe when used in string interpolation' do
        output = "Debug token: #{token.inspect}"
        expect(output).not_to include(password)
      end

      it 'is safe when used in exception messages' do
        raise StandardError, "Token error: #{token.inspect}"
      rescue StandardError => e
        expect(e.message).not_to include(password)
        expect(e.message).to include('[REDACTED]')
      end

      it 'is safe when token is in an array' do
        array = [token, 'other']
        output = array.inspect
        expect(output).not_to include(password)
        expect(output).to include('[REDACTED]')
      end

      it 'is safe when token is in a hash' do
        hash = { token: token, name: 'test' }
        output = hash.inspect
        expect(output).not_to include(password)
        expect(output).to include('[REDACTED]')
      end

      it 'never exposes sensitive data regardless of password content' do
        dangerous_password = '"><script>alert(1)</script>'
        dangerous_token = described_class.new(username, dangerous_password, digest: true)

        expect(dangerous_token.inspect).not_to include(dangerous_password)
        expect(dangerous_token.inspect).not_to include('script')
      end
    end
  end
end
