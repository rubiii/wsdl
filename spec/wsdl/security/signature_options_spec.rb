# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::SignatureOptions do
  describe 'DEFAULTS' do
    it 'has sign_timestamp defaulting to true' do
      expect(described_class::DEFAULTS[:sign_timestamp]).to be true
    end

    it 'has sign_addressing defaulting to false' do
      expect(described_class::DEFAULTS[:sign_addressing]).to be false
    end

    it 'has explicit_namespace_prefixes defaulting to false' do
      expect(described_class::DEFAULTS[:explicit_namespace_prefixes]).to be false
    end

    it 'has key_reference defaulting to binary_security_token' do
      expect(described_class::DEFAULTS[:key_reference]).to eq(:binary_security_token)
    end

    it 'has digest_algorithm defaulting to sha256' do
      expect(described_class::DEFAULTS[:digest_algorithm]).to eq(:sha256)
    end
  end

  describe '.from_hash' do
    context 'with empty hash' do
      subject(:options) { described_class.from_hash({}) }

      it 'uses defaults for all options' do
        expect(options.sign_timestamp?).to be true
        expect(options.sign_addressing?).to be false
        expect(options.explicit_namespace_prefixes?).to be false
        expect(options.key_reference).to eq(:binary_security_token)
        expect(options.digest_algorithm).to eq(:sha256)
      end
    end

    context 'with partial hash' do
      subject(:options) { described_class.from_hash(sign_addressing: true) }

      it 'uses provided values and defaults for missing values' do
        expect(options.sign_timestamp?).to be true
        expect(options.sign_addressing?).to be true
        expect(options.explicit_namespace_prefixes?).to be false
      end
    end

    context 'with complete hash' do
      subject(:options) do
        described_class.from_hash(
          sign_timestamp: false,
          sign_addressing: true,
          explicit_namespace_prefixes: true,
          key_reference: :issuer_serial,
          digest_algorithm: :sha512
        )
      end

      it 'uses all provided values' do
        expect(options.sign_timestamp?).to be false
        expect(options.sign_addressing?).to be true
        expect(options.explicit_namespace_prefixes?).to be true
        expect(options.key_reference).to eq(:issuer_serial)
        expect(options.digest_algorithm).to eq(:sha512)
      end
    end
  end

  describe '#sign_timestamp?' do
    it 'returns true when sign_timestamp is true' do
      options = described_class.from_hash(sign_timestamp: true)
      expect(options.sign_timestamp?).to be true
    end

    it 'returns false when sign_timestamp is false' do
      options = described_class.from_hash(sign_timestamp: false)
      expect(options.sign_timestamp?).to be false
    end
  end

  describe '#sign_addressing?' do
    it 'returns true when sign_addressing is true' do
      options = described_class.from_hash(sign_addressing: true)
      expect(options.sign_addressing?).to be true
    end

    it 'returns false when sign_addressing is false' do
      options = described_class.from_hash(sign_addressing: false)
      expect(options.sign_addressing?).to be false
    end
  end

  describe '#explicit_namespace_prefixes?' do
    it 'returns true when explicit_namespace_prefixes is true' do
      options = described_class.from_hash(explicit_namespace_prefixes: true)
      expect(options.explicit_namespace_prefixes?).to be true
    end

    it 'returns false when explicit_namespace_prefixes is false' do
      options = described_class.from_hash(explicit_namespace_prefixes: false)
      expect(options.explicit_namespace_prefixes?).to be false
    end
  end

  describe '#key_reference' do
    it 'returns :binary_security_token by default' do
      options = described_class.from_hash({})
      expect(options.key_reference).to eq(:binary_security_token)
    end

    it 'returns :issuer_serial when set' do
      options = described_class.from_hash(key_reference: :issuer_serial)
      expect(options.key_reference).to eq(:issuer_serial)
    end

    it 'returns :subject_key_identifier when set' do
      options = described_class.from_hash(key_reference: :subject_key_identifier)
      expect(options.key_reference).to eq(:subject_key_identifier)
    end
  end

  describe '#digest_algorithm' do
    it 'returns :sha256 by default' do
      options = described_class.from_hash({})
      expect(options.digest_algorithm).to eq(:sha256)
    end

    it 'returns :sha1 when set' do
      options = described_class.from_hash(digest_algorithm: :sha1)
      expect(options.digest_algorithm).to eq(:sha1)
    end

    it 'returns :sha512 when set' do
      options = described_class.from_hash(digest_algorithm: :sha512)
      expect(options.digest_algorithm).to eq(:sha512)
    end
  end

  describe '#to_h' do
    subject(:options) do
      described_class.from_hash(
        sign_timestamp: true,
        sign_addressing: true,
        explicit_namespace_prefixes: false,
        key_reference: :issuer_serial,
        digest_algorithm: :sha512
      )
    end

    it 'returns a hash with all option values' do
      expect(options.to_h).to eq(
        sign_timestamp: true,
        sign_addressing: true,
        explicit_namespace_prefixes: false,
        key_reference: :issuer_serial,
        digest_algorithm: :sha512
      )
    end
  end

  describe '#==' do
    let(:options1) do
      described_class.from_hash(
        sign_addressing: true,
        key_reference: :issuer_serial
      )
    end

    context 'when comparing equal options' do
      let(:options2) do
        described_class.from_hash(
          sign_addressing: true,
          key_reference: :issuer_serial
        )
      end

      it 'returns true' do
        expect(options1 == options2).to be true
      end
    end

    context 'when sign_timestamp differs' do
      let(:options2) do
        described_class.from_hash(
          sign_timestamp: false,
          sign_addressing: true,
          key_reference: :issuer_serial
        )
      end

      it 'returns false' do
        expect(options1 == options2).to be false
      end
    end

    context 'when key_reference differs' do
      let(:options2) do
        described_class.from_hash(
          sign_addressing: true,
          key_reference: :binary_security_token
        )
      end

      it 'returns false' do
        expect(options1 == options2).to be false
      end
    end

    context 'when comparing with non-SignatureOptions object' do
      it 'returns false' do
        expect(options1 == 'not options').to be false
      end
    end
  end

  describe '#eql?' do
    it 'is aliased to ==' do
      options1 = described_class.from_hash(sign_addressing: true)
      options2 = described_class.from_hash(sign_addressing: true)

      expect(options1.eql?(options2)).to be true
    end
  end

  describe '#hash' do
    it 'returns the same hash for equal options' do
      options1 = described_class.from_hash(sign_addressing: true, key_reference: :issuer_serial)
      options2 = described_class.from_hash(sign_addressing: true, key_reference: :issuer_serial)

      expect(options1.hash).to eq(options2.hash)
    end

    it 'returns different hashes for different options' do
      options1 = described_class.from_hash(sign_timestamp: true)
      options2 = described_class.from_hash(sign_timestamp: false)

      expect(options1.hash).not_to eq(options2.hash)
    end

    it 'allows options to be used as hash keys' do
      options1 = described_class.from_hash(sign_addressing: true)
      options2 = described_class.from_hash(sign_addressing: true)

      hash = { options1 => 'value' }
      expect(hash[options2]).to eq('value')
    end
  end
end
