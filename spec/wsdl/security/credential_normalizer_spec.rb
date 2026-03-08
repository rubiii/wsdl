# frozen_string_literal: true

RSpec.describe WSDL::Security::CredentialNormalizer do
  subject(:normalizer) { described_class.new }

  describe '#validate_key_reference!' do
    let(:private_key) { OpenSSL::PKey::RSA.new(1024) }
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

    context 'with :subject_key_identifier' do
      let(:certificate_with_ski) do
        cert = OpenSSL::X509::Certificate.new
        cert.version = 2
        cert.serial = 1
        cert.subject = OpenSSL::X509::Name.new([['CN', 'With SKI']])
        cert.issuer = cert.subject
        cert.public_key = private_key.public_key
        cert.not_before = Time.now
        cert.not_after = Time.now + 3600

        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate = cert
        cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))

        cert.sign(private_key, OpenSSL::Digest.new('SHA256'))
        cert
      end

      it 'accepts a certificate that has a Subject Key Identifier extension' do
        expect {
          normalizer.validate_key_reference!(:subject_key_identifier, certificate_with_ski)
        }.not_to raise_error
      end

      it 'raises ArgumentError when the certificate lacks a Subject Key Identifier extension' do
        expect {
          normalizer.validate_key_reference!(:subject_key_identifier, certificate_without_ski)
        }.to raise_error(ArgumentError, /does not have a Subject Key Identifier extension/)
      end
    end

    context 'with other valid key references' do
      it 'accepts :binary_security_token without checking SKI' do
        expect {
          normalizer.validate_key_reference!(:binary_security_token, certificate_without_ski)
        }.not_to raise_error
      end

      it 'accepts :issuer_serial without checking SKI' do
        expect {
          normalizer.validate_key_reference!(:issuer_serial, certificate_without_ski)
        }.not_to raise_error
      end
    end
  end
end
