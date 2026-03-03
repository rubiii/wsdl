# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::ResponsePolicy do
  describe '.default' do
    it 'returns a frozen disabled policy with default options' do
      policy = described_class.default

      expect(policy).to be_frozen
      expect(policy.mode).to eq(described_class::MODE_DISABLED)
      expect(policy.disabled?).to be(true)
      expect(policy.options).to eq(WSDL::Security::ResponseVerification::Options.default)
    end
  end

  describe '#initialize' do
    it 'raises for unknown mode' do
      expect {
        described_class.new(mode: :legacy, options: WSDL::Security::ResponseVerification::Options.default)
      }.to raise_error(ArgumentError, /Invalid response verification mode/)
    end
  end

  describe '#with_mode and #with_options' do
    it 'returns new frozen instances' do
      policy = described_class.default
      strict = policy.with_mode(described_class::MODE_REQUIRED)
      options = WSDL::Security::ResponseVerification::Options.new(
        certificate: WSDL::Security::ResponseVerification::Certificate.new(
          trust_store: :system,
          verify_not_expired: true
        ),
        timestamp: WSDL::Security::ResponseVerification::Timestamp.new(
          validate: false,
          tolerance_seconds: 60
        )
      )
      updated = strict.with_options(options)

      expect(strict).to be_frozen
      expect(updated).to be_frozen
      expect(policy.mode).to eq(described_class::MODE_DISABLED)
      expect(strict.mode).to eq(described_class::MODE_REQUIRED)
      expect(updated.options.timestamp.validate).to be(false)
      expect(updated.options.timestamp.tolerance_seconds).to eq(60)
    end
  end
end
