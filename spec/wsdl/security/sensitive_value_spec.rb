# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::SensitiveValue do
  subject(:sensitive) { described_class.new(secret) }

  let(:secret) { 'super_secret_password_123' }

  describe '#initialize' do
    it 'wraps the provided value' do
      expect(sensitive.value).to eq(secret)
    end

    it 'can wrap nil values' do
      nil_sensitive = described_class.new(nil)
      expect(nil_sensitive.value).to be_nil
    end

    it 'can wrap complex objects' do
      hash = { password: 'secret', data: [1, 2, 3] }
      sensitive = described_class.new(hash)
      expect(sensitive.value).to eq(hash)
    end
  end

  describe '#value' do
    it 'returns the original unwrapped value' do
      expect(sensitive.value).to eq(secret)
    end

    it 'returns the exact same object' do
      obj = Object.new
      sensitive = described_class.new(obj)
      expect(sensitive.value).to be(obj)
    end
  end

  describe '#inspect' do
    it 'returns a redacted representation' do
      expect(sensitive.inspect).to eq('#<WSDL::Security::SensitiveValue [REDACTED]>')
    end

    it 'never includes the actual value' do
      expect(sensitive.inspect).not_to include(secret)
    end

    it 'is safe even with special characters in the value' do
      dangerous = described_class.new('"><script>alert(1)</script>')
      expect(dangerous.inspect).not_to include('script')
      expect(dangerous.inspect).to eq('#<WSDL::Security::SensitiveValue [REDACTED]>')
    end

    it 'works in string interpolation via inspect' do
      # When objects appear in debug output, inspect is typically called
      output = "Debug: #{sensitive.inspect}"
      expect(output).not_to include(secret)
      expect(output).to include('[REDACTED]')
    end
  end

  describe '#to_s' do
    it 'returns the redacted placeholder' do
      expect(sensitive.to_s).to eq('[REDACTED]')
    end

    it 'never includes the actual value' do
      expect(sensitive.to_s).not_to include(secret)
    end

    it 'is safe in string interpolation' do
      output = "Password: #{sensitive}"
      expect(output).to eq('Password: [REDACTED]')
      expect(output).not_to include(secret)
    end

    it 'is safe when concatenated' do
      output = "Secret: #{sensitive}"
      expect(output).not_to include(secret)
    end
  end

  describe '#==' do
    it 'returns true when comparing equal values' do
      other = described_class.new(secret)
      expect(sensitive == other).to be true
    end

    it 'returns false when comparing different values' do
      other = described_class.new('different_secret')
      expect(sensitive == other).to be false
    end

    it 'can compare with raw values' do
      expect(sensitive == secret).to be true
      expect(sensitive == 'wrong').to be false
    end

    it 'handles nil comparisons' do
      nil_sensitive = described_class.new(nil)
      expect(nil_sensitive.nil?).to be true
      expect(sensitive.nil?).to be false
    end
  end

  describe '#nil?' do
    it 'returns false when value is not nil' do
      expect(sensitive.nil?).to be false
    end

    it 'returns true when value is nil' do
      nil_sensitive = described_class.new(nil)
      expect(nil_sensitive.nil?).to be true
    end
  end

  describe '#present?' do
    it 'returns true when value is present' do
      expect(sensitive.present?).to be true
    end

    it 'returns false when value is nil' do
      nil_sensitive = described_class.new(nil)
      expect(nil_sensitive.present?).to be false
    end

    it 'returns false when value is empty string' do
      empty_sensitive = described_class.new('')
      expect(empty_sensitive.present?).to be false
    end

    it 'returns false when value is empty array' do
      empty_sensitive = described_class.new([])
      expect(empty_sensitive.present?).to be false
    end

    it 'returns true when value is non-empty array' do
      array_sensitive = described_class.new([1, 2, 3])
      expect(array_sensitive.present?).to be true
    end
  end

  describe '#marshal_dump' do
    it 'raises SecurityError to prevent serialization' do
      expect { Marshal.dump(sensitive) }.to raise_error(SecurityError, /Cannot marshal sensitive values/)
    end

    it 'includes a helpful error message' do
      expect { sensitive.marshal_dump }.to raise_error(SecurityError, /expose secrets/)
    end
  end

  describe '#marshal_load' do
    it 'raises SecurityError to prevent deserialization' do
      expect { sensitive.marshal_load('data') }.to raise_error(SecurityError, /Cannot unmarshal/)
    end
  end

  describe '#to_json' do
    it 'returns the redacted placeholder as JSON' do
      expect(sensitive.to_json).to eq('"[REDACTED]"')
    end

    it 'never includes the actual value' do
      expect(sensitive.to_json).not_to include(secret)
    end
  end

  describe '#to_yaml' do
    it 'returns the redacted placeholder as YAML' do
      yaml_output = sensitive.to_yaml
      expect(yaml_output).to include('[REDACTED]')
      expect(yaml_output).not_to include(secret)
    end
  end

  describe '#dup' do
    it 'creates a new SensitiveValue instance' do
      duped = sensitive.dup
      expect(duped).to be_a(described_class)
      expect(duped).not_to be(sensitive)
    end

    it 'wraps the same value' do
      duped = sensitive.dup
      expect(duped.value).to eq(sensitive.value)
    end
  end

  describe '#clone' do
    it 'creates a new SensitiveValue instance' do
      cloned = sensitive.clone
      expect(cloned).to be_a(described_class)
      expect(cloned).not_to be(sensitive)
    end

    it 'wraps an equivalent value' do
      cloned = sensitive.clone
      expect(cloned.value).to eq(sensitive.value)
    end
  end

  describe 'REDACTED constant' do
    it 'is defined' do
      expect(described_class::REDACTED).to eq('[REDACTED]')
    end

    it 'is frozen' do
      expect(described_class::REDACTED).to be_frozen
    end
  end

  describe 'security scenarios' do
    context 'when value appears in exception backtrace' do
      it 'does not expose the value' do
        raise StandardError, "Error with #{sensitive.inspect}"
      rescue StandardError => e
        expect(e.message).not_to include(secret)
        expect(e.message).to include('[REDACTED]')
      end
    end

    context 'when used in array inspection' do
      it 'does not expose the value' do
        array = [1, sensitive, 'visible']
        output = array.inspect
        expect(output).not_to include(secret)
        expect(output).to include('[REDACTED]')
      end
    end

    context 'when used in hash inspection' do
      it 'does not expose the value' do
        hash = { password: sensitive, username: 'admin' }
        output = hash.inspect
        expect(output).not_to include(secret)
        expect(output).to include('[REDACTED]')
      end
    end

    context 'when object is p() printed' do
      it 'does not expose the value' do
        # p() calls inspect internally
        output = sensitive.inspect
        expect(output).not_to include(secret)
      end
    end

    context 'with OpenSSL private key' do
      it 'protects the key material' do
        # Simulate wrapping a private key (we use a string to avoid slow key generation)
        key_pem = "-----BEGIN RSA PRIVATE KEY-----\nMIIE...\n-----END RSA PRIVATE KEY-----"
        sensitive_key = described_class.new(key_pem)

        expect(sensitive_key.inspect).not_to include('BEGIN')
        expect(sensitive_key.inspect).not_to include('PRIVATE KEY')
        expect(sensitive_key.to_s).not_to include('BEGIN')
      end
    end

    context 'with binary data (like nonces)' do
      it 'protects binary values' do
        nonce = SecureRandom.random_bytes(16)
        sensitive_nonce = described_class.new(nonce)

        expect(sensitive_nonce.inspect).not_to include(nonce.inspect)
        expect(sensitive_nonce.value).to eq(nonce)
      end
    end
  end
end
