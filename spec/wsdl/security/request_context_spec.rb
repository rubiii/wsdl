# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::RequestContext do
  let(:signature_options) do
    WSDL::Security::Signature.new(
      certificate: certificate,
      private_key: private_key,
      digest_algorithm: :sha256,
      explicit_namespace_prefixes: true,
      key_reference: :issuer_serial
    )
  end

  let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:certificate) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.new([%w[CN Test]])
    cert.issuer = cert.subject
    cert.public_key = private_key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
    cert
  end

  describe '#configured?' do
    it 'returns false when nothing is configured' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: nil,
        signature_config: nil,
        signature_options: nil
      )
      expect(ctx.configured?).to be false
    end

    it 'returns true when only timestamp is configured' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: :present,
        signature_config: nil,
        signature_options: nil
      )
      expect(ctx.configured?).to be true
    end
  end

  describe '#explicit_namespace_prefixes?' do
    it 'returns false when signature_options is nil' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: nil,
        signature_config: nil,
        signature_options: nil
      )
      expect(ctx.explicit_namespace_prefixes?).to be false
    end

    it 'returns true when signature_options has explicit prefixes' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: nil,
        signature_config: nil,
        signature_options: signature_options
      )
      expect(ctx.explicit_namespace_prefixes?).to be true
    end
  end

  describe '#key_reference' do
    it 'returns default when signature_options is nil' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: nil,
        signature_config: nil,
        signature_options: nil
      )
      expect(ctx.key_reference).to eq(:binary_security_token)
    end

    it 'returns the configured key_reference' do
      ctx = described_class.new(
        username_token_config: nil,
        timestamp_config: nil,
        signature_config: nil,
        signature_options: signature_options
      )
      expect(ctx.key_reference).to eq(:issuer_serial)
    end
  end
end
