# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::CredentialNormalizer do
  subject(:normalizer) { described_class.new }

  describe '#validate_key_reference!' do
    let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:certificate_without_ski) do
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.new([['CN', 'No SKI']])
      cert.issuer = cert.subject
      cert.public_key = private_key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + 3600
      cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
      cert
    end

    it 'raises ArgumentError for invalid key_reference' do
      expect {
        normalizer.validate_key_reference!(:bogus, certificate_without_ski)
      }.to raise_error(ArgumentError, /Invalid key_reference.*:bogus/)
    end
  end
end
