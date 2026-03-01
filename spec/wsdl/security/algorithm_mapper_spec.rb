# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Security::AlgorithmMapper do
  describe '.c14n_algorithm' do
    context 'with exclusive canonicalization URI' do
      it 'returns :exclusive_1_0 for xml-exc-c14n URI' do
        uri = 'http://www.w3.org/2001/10/xml-exc-c14n#'
        expect(described_class.c14n_algorithm(uri)).to eq(:exclusive_1_0)
      end
    end

    context 'with inclusive canonicalization 1.0 URI' do
      it 'returns :inclusive_1_0 for REC-xml-c14n-20010315 URI' do
        uri = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_0)
      end

      it 'returns :inclusive_1_0 for REC-xml-c14n-20010315 with comments' do
        uri = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_0)
      end
    end

    context 'with inclusive canonicalization 1.1 URI' do
      it 'returns :inclusive_1_1 for xml-c14n11 URI' do
        uri = 'http://www.w3.org/2006/12/xml-c14n11'
        expect(described_class.c14n_algorithm(uri)).to eq(:inclusive_1_1)
      end
    end

    context 'with nil URI' do
      it 'returns :exclusive_1_0 as default' do
        expect(described_class.c14n_algorithm(nil)).to eq(:exclusive_1_0)
      end
    end

    context 'with unknown URI' do
      it 'returns :exclusive_1_0 as default' do
        expect(described_class.c14n_algorithm('http://unknown/algorithm')).to eq(:exclusive_1_0)
      end
    end
  end

  describe '.digest_algorithm' do
    context 'with SHA-256 URI' do
      it 'returns :sha256 for xmlenc#sha256' do
        uri = 'http://www.w3.org/2001/04/xmlenc#sha256'
        expect(described_class.digest_algorithm(uri)).to eq(:sha256)
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/SHA256'
        expect(described_class.digest_algorithm(uri)).to eq(:sha256)
      end
    end

    context 'with SHA-512 URI' do
      it 'returns :sha512 for xmlenc#sha512' do
        uri = 'http://www.w3.org/2001/04/xmlenc#sha512'
        expect(described_class.digest_algorithm(uri)).to eq(:sha512)
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/SHA512'
        expect(described_class.digest_algorithm(uri)).to eq(:sha512)
      end
    end

    context 'with SHA-1 URI' do
      it 'returns :sha1 for xmldsig#sha1' do
        uri = 'http://www.w3.org/2000/09/xmldsig#sha1'
        expect(described_class.digest_algorithm(uri)).to eq(:sha1)
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/SHA1'
        expect(described_class.digest_algorithm(uri)).to eq(:sha1)
      end
    end

    context 'with nil URI' do
      it 'returns :sha256 as default' do
        expect(described_class.digest_algorithm(nil)).to eq(:sha256)
      end
    end

    context 'with unknown URI' do
      it 'returns :sha256 as default' do
        expect(described_class.digest_algorithm('http://unknown/digest')).to eq(:sha256)
      end
    end
  end

  describe '.signature_digest' do
    context 'with RSA-SHA256 URI' do
      it 'returns SHA256 for rsa-sha256 URI' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/RSA-SHA256'
        expect(described_class.signature_digest(uri)).to eq('SHA256')
      end
    end

    context 'with RSA-SHA512 URI' do
      it 'returns SHA512 for rsa-sha512 URI' do
        uri = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'
        expect(described_class.signature_digest(uri)).to eq('SHA512')
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/RSA-SHA512'
        expect(described_class.signature_digest(uri)).to eq('SHA512')
      end
    end

    context 'with RSA-SHA1 URI' do
      it 'returns SHA1 for rsa-sha1 URI' do
        uri = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
        expect(described_class.signature_digest(uri)).to eq('SHA1')
      end

      it 'handles case-insensitive matching' do
        uri = 'http://example.com/RSA-SHA1'
        expect(described_class.signature_digest(uri)).to eq('SHA1')
      end
    end

    context 'with nil URI' do
      it 'returns SHA256 as default' do
        expect(described_class.signature_digest(nil)).to eq('SHA256')
      end
    end

    context 'with unknown URI' do
      it 'returns SHA256 as default' do
        expect(described_class.signature_digest('http://unknown/signature')).to eq('SHA256')
      end
    end
  end

  describe 'algorithm priority' do
    it 'matches sha512 before sha1 when both could match' do
      # This tests that sha512 comes first in the mapping order
      uri = 'http://example.com/sha512'
      expect(described_class.digest_algorithm(uri)).to eq(:sha512)
    end

    it 'matches rsa-sha512 before rsa-sha1 when both could match' do
      uri = 'http://example.com/rsa-sha512'
      expect(described_class.signature_digest(uri)).to eq('SHA512')
    end
  end
end
