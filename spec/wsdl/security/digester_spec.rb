# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Digester do
  describe 'ALGORITHMS' do
    it 'includes sha1 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:sha1)
    end

    it 'includes sha256 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:sha256)
    end

    it 'includes sha512 algorithm' do
      expect(described_class::ALGORITHMS).to have_key(:sha512)
    end
  end

  describe 'DEFAULT_ALGORITHM' do
    it 'defaults to sha256' do
      expect(described_class::DEFAULT_ALGORITHM).to eq(:sha256)
    end
  end

  describe '#initialize' do
    context 'with default algorithm' do
      subject(:digester) { described_class.new }

      it 'uses sha256 by default' do
        expect(digester.algorithm_key).to eq(:sha256)
      end
    end

    context 'with specified algorithm' do
      it 'accepts :sha1' do
        digester = described_class.new(algorithm: :sha1)
        expect(digester.algorithm_key).to eq(:sha1)
      end

      it 'accepts :sha256' do
        digester = described_class.new(algorithm: :sha256)
        expect(digester.algorithm_key).to eq(:sha256)
      end

      it 'accepts :sha512' do
        digester = described_class.new(algorithm: :sha512)
        expect(digester.algorithm_key).to eq(:sha512)
      end
    end

    context 'with unknown algorithm' do
      it 'raises ArgumentError' do
        expect { described_class.new(algorithm: :md5) }.to raise_error(
          ArgumentError, /Unknown digest algorithm: :md5/
        )
      end
    end
  end

  describe '#digest' do
    let(:data) { 'hello world' }

    context 'with SHA-1' do
      subject(:digester) { described_class.new(algorithm: :sha1) }

      it 'returns raw binary digest' do
        digest = digester.digest(data)
        expect(digest.bytesize).to eq(20) # SHA-1 produces 160 bits = 20 bytes
      end

      it 'matches OpenSSL::Digest::SHA1 output' do
        expected = OpenSSL::Digest::SHA1.digest(data)
        expect(digester.digest(data)).to eq(expected)
      end
    end

    context 'with SHA-256' do
      subject(:digester) { described_class.new(algorithm: :sha256) }

      it 'returns raw binary digest' do
        digest = digester.digest(data)
        expect(digest.bytesize).to eq(32) # SHA-256 produces 256 bits = 32 bytes
      end

      it 'matches OpenSSL::Digest::SHA256 output' do
        expected = OpenSSL::Digest::SHA256.digest(data)
        expect(digester.digest(data)).to eq(expected)
      end
    end

    context 'with SHA-512' do
      subject(:digester) { described_class.new(algorithm: :sha512) }

      it 'returns raw binary digest' do
        digest = digester.digest(data)
        expect(digest.bytesize).to eq(64) # SHA-512 produces 512 bits = 64 bytes
      end

      it 'matches OpenSSL::Digest::SHA512 output' do
        expected = OpenSSL::Digest::SHA512.digest(data)
        expect(digester.digest(data)).to eq(expected)
      end
    end
  end

  describe '#base64_digest' do
    let(:data) { 'hello world' }

    context 'with SHA-256' do
      subject(:digester) { described_class.new(algorithm: :sha256) }

      it 'returns Base64-encoded digest' do
        base64_digest = digester.base64_digest(data)
        expect(base64_digest).to be_a(String)
      end

      it 'does not include newlines' do
        base64_digest = digester.base64_digest(data)
        expect(base64_digest).not_to include("\n")
      end

      it 'can be decoded back to raw digest' do
        base64_digest = digester.base64_digest(data)
        decoded = Base64.strict_decode64(base64_digest)
        expect(decoded).to eq(digester.digest(data))
      end

      it 'produces correct known value' do
        # SHA-256 of "hello world" is well-known
        expected = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(data))
        expect(digester.base64_digest(data)).to eq(expected)
      end
    end
  end

  describe '#hex_digest' do
    let(:data) { 'hello world' }

    context 'with SHA-256' do
      subject(:digester) { described_class.new(algorithm: :sha256) }

      it 'returns hexadecimal digest' do
        hex_digest = digester.hex_digest(data)
        expect(hex_digest).to match(/\A[a-f0-9]+\z/)
      end

      it 'matches OpenSSL hexdigest' do
        expected = OpenSSL::Digest::SHA256.hexdigest(data)
        expect(digester.hex_digest(data)).to eq(expected)
      end

      it 'has correct length' do
        hex_digest = digester.hex_digest(data)
        expect(hex_digest.length).to eq(64) # SHA-256 = 32 bytes = 64 hex chars
      end
    end
  end

  describe '#algorithm_id' do
    it 'returns correct URI for SHA-1' do
      digester = described_class.new(algorithm: :sha1)
      expect(digester.algorithm_id).to eq('http://www.w3.org/2000/09/xmldsig#sha1')
    end

    it 'returns correct URI for SHA-256' do
      digester = described_class.new(algorithm: :sha256)
      expect(digester.algorithm_id).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
    end

    it 'returns correct URI for SHA-512' do
      digester = described_class.new(algorithm: :sha512)
      expect(digester.algorithm_id).to eq('http://www.w3.org/2001/04/xmlenc#sha512')
    end
  end

  describe '#algorithm_name' do
    it 'returns SHA1 for :sha1' do
      digester = described_class.new(algorithm: :sha1)
      expect(digester.algorithm_name).to eq('SHA1')
    end

    it 'returns SHA256 for :sha256' do
      digester = described_class.new(algorithm: :sha256)
      expect(digester.algorithm_name).to eq('SHA256')
    end

    it 'returns SHA512 for :sha512' do
      digester = described_class.new(algorithm: :sha512)
      expect(digester.algorithm_name).to eq('SHA512')
    end
  end

  describe '#digest_length' do
    it 'returns 20 for SHA-1' do
      digester = described_class.new(algorithm: :sha1)
      expect(digester.digest_length).to eq(20)
    end

    it 'returns 32 for SHA-256' do
      digester = described_class.new(algorithm: :sha256)
      expect(digester.digest_length).to eq(32)
    end

    it 'returns 64 for SHA-512' do
      digester = described_class.new(algorithm: :sha512)
      expect(digester.digest_length).to eq(64)
    end
  end

  describe '#new_digest' do
    subject(:digester) { described_class.new(algorithm: :sha256) }

    it 'returns a new OpenSSL::Digest instance' do
      digest_instance = digester.new_digest
      expect(digest_instance).to be_a(OpenSSL::Digest)
    end

    it 'returns independent instances' do
      digest1 = digester.new_digest
      digest2 = digester.new_digest
      expect(digest1).not_to equal(digest2)
    end

    it 'can be used for incremental digesting' do
      digest_instance = digester.new_digest
      digest_instance.update('hello ')
      digest_instance.update('world')

      expected = digester.digest('hello world')
      expect(digest_instance.digest).to eq(expected)
    end
  end

  describe '.digest (class method)' do
    let(:data) { 'hello world' }

    it 'computes digest with default algorithm' do
      result = described_class.digest(data)
      expected = OpenSSL::Digest::SHA256.digest(data)
      expect(result).to eq(expected)
    end

    it 'accepts custom algorithm' do
      result = described_class.digest(data, algorithm: :sha1)
      expected = OpenSSL::Digest::SHA1.digest(data)
      expect(result).to eq(expected)
    end

    it 'returns Base64 with encode: :base64' do
      result = described_class.digest(data, encode: :base64)
      expected = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(data))
      expect(result).to eq(expected)
    end

    it 'returns hex with encode: :hex' do
      result = described_class.digest(data, encode: :hex)
      expected = OpenSSL::Digest::SHA256.hexdigest(data)
      expect(result).to eq(expected)
    end
  end

  describe '.base64_digest (class method)' do
    let(:data) { 'hello world' }

    it 'computes Base64-encoded digest with default algorithm' do
      result = described_class.base64_digest(data)
      expected = Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(data))
      expect(result).to eq(expected)
    end

    it 'accepts custom algorithm' do
      result = described_class.base64_digest(data, algorithm: :sha1)
      expected = Base64.strict_encode64(OpenSSL::Digest::SHA1.digest(data))
      expect(result).to eq(expected)
    end
  end

  describe 'digest consistency' do
    let(:data) { 'consistent input' }

    it 'produces same digest for same input' do
      digester = described_class.new
      digest1 = digester.digest(data)
      digest2 = digester.digest(data)

      expect(digest1).to eq(digest2)
    end

    it 'produces different digests for different inputs' do
      digester = described_class.new
      digest1 = digester.digest('input 1')
      digest2 = digester.digest('input 2')

      expect(digest1).not_to eq(digest2)
    end
  end

  describe 'XML canonicalized content digesting' do
    let(:xml_content) { '<root><child>text</child></root>' }

    it 'can digest XML content' do
      digester = described_class.new(algorithm: :sha256)
      digest = digester.base64_digest(xml_content)

      # Should produce a valid Base64 string
      expect { Base64.strict_decode64(digest) }.not_to raise_error
    end
  end
end
