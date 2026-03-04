# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::RequestPolicy do
  describe '.empty' do
    it 'returns a frozen unconfigured policy' do
      policy = described_class.empty

      expect(policy).to be_frozen
      expect(policy.configured?).to be(false)
      expect(policy.username_token?).to be(false)
      expect(policy.timestamp?).to be(false)
      expect(policy.signature?).to be(false)
    end
  end

  describe '#with_*' do
    let(:base_policy) { described_class.empty }

    it 'returns new frozen instances and preserves previous values' do
      token_policy = described_class::UsernameToken.new(
        username: 'user',
        password: 'secret',
        digest: true,
        created_at: nil
      )

      updated = base_policy.with_username_token(token_policy)

      expect(updated).to be_frozen
      expect(updated).not_to equal(base_policy)
      expect(base_policy.username_token?).to be(false)
      expect(updated.username_token?).to be(true)
    end

    it 'derives signature flags from signature options' do
      options = WSDL::Security::SignatureOptions.from_hash(
        sign_timestamp: true,
        sign_addressing: true,
        explicit_namespace_prefixes: true,
        key_reference: :issuer_serial,
        digest_algorithm: :sha512
      ).freeze

      signature_policy = described_class::Signature.new(
        certificate: Object.new,
        private_key: Object.new,
        options:
      )

      policy = base_policy.with_signature(signature_policy)

      expect(policy.sign_timestamp?).to be(false)
      expect(policy.sign_addressing?).to be(true)
      expect(policy.explicit_namespace_prefixes?).to be(true)
      expect(policy.key_reference).to eq(:issuer_serial)
    end
  end
end
