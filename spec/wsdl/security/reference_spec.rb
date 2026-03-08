# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Reference do
  describe '#initialize' do
    context 'with required arguments' do
      subject(:reference) { described_class.new(id: 'Body-123', digest_value: 'abc123') }

      it 'sets the id' do
        expect(reference.id).to eq('Body-123')
      end

      it 'sets the digest_value' do
        expect(reference.digest_value).to eq('abc123')
      end

      it 'sets inclusive_namespaces to nil by default' do
        expect(reference.inclusive_namespaces).to be_nil
      end
    end

    context 'with inclusive_namespaces' do
      subject(:reference) do
        described_class.new(
          id: 'Body-123',
          digest_value: 'abc123',
          inclusive_namespaces: %w[soap wsu]
        )
      end

      it 'sets the inclusive_namespaces' do
        expect(reference.inclusive_namespaces).to eq(%w[soap wsu])
      end
    end
  end

  describe '#uri' do
    subject(:reference) { described_class.new(id: 'Body-abc123', digest_value: 'xyz') }

    it 'returns the id with # prefix' do
      expect(reference.uri).to eq('#Body-abc123')
    end
  end

  describe '#inclusive_namespaces?' do
    context 'when inclusive_namespaces is nil' do
      subject(:reference) { described_class.new(id: 'Body-123', digest_value: 'abc') }

      it 'returns false' do
        expect(reference.inclusive_namespaces?).to be false
      end
    end

    context 'when inclusive_namespaces is empty' do
      subject(:reference) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: [])
      end

      it 'returns false' do
        expect(reference.inclusive_namespaces?).to be false
      end
    end

    context 'when inclusive_namespaces has values' do
      subject(:reference) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])
      end

      it 'returns true' do
        expect(reference.inclusive_namespaces?).to be true
      end
    end
  end

  describe '#prefix_list' do
    context 'when inclusive_namespaces is nil' do
      subject(:reference) { described_class.new(id: 'Body-123', digest_value: 'abc') }

      it 'returns nil' do
        expect(reference.prefix_list).to be_nil
      end
    end

    context 'when inclusive_namespaces is empty' do
      subject(:reference) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: [])
      end

      it 'returns nil' do
        expect(reference.prefix_list).to be_nil
      end
    end

    context 'when inclusive_namespaces has one value' do
      subject(:reference) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])
      end

      it 'returns the single prefix' do
        expect(reference.prefix_list).to eq('soap')
      end
    end

    context 'when inclusive_namespaces has multiple values' do
      subject(:reference) do
        described_class.new(
          id: 'Body-123',
          digest_value: 'abc',
          inclusive_namespaces: %w[soap wsu wsse]
        )
      end

      it 'returns space-separated prefixes' do
        expect(reference.prefix_list).to eq('soap wsu wsse')
      end
    end
  end

  describe '#to_h' do
    subject(:reference) do
      described_class.new(
        id: 'Body-123',
        digest_value: 'abc123',
        inclusive_namespaces: %w[soap wsu]
      )
    end

    it 'returns a hash representation' do
      expect(reference.to_h).to eq(
        id: 'Body-123',
        digest_value: 'abc123',
        inclusive_namespaces: %w[soap wsu]
      )
    end
  end

  describe '#==' do
    let(:reference1) do
      described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])
    end

    context 'when comparing equal references' do
      let(:reference2) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])
      end

      it 'returns true' do
        expect(reference1 == reference2).to be true
      end
    end

    context 'when id differs' do
      let(:reference2) do
        described_class.new(id: 'Body-456', digest_value: 'abc', inclusive_namespaces: ['soap'])
      end

      it 'returns false' do
        expect(reference1 == reference2).to be false
      end
    end

    context 'when digest_value differs' do
      let(:reference2) do
        described_class.new(id: 'Body-123', digest_value: 'xyz', inclusive_namespaces: ['soap'])
      end

      it 'returns false' do
        expect(reference1 == reference2).to be false
      end
    end

    context 'when inclusive_namespaces differs' do
      let(:reference2) do
        described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['wsu'])
      end

      it 'returns false' do
        expect(reference1 == reference2).to be false
      end
    end

    context 'when comparing with non-Reference object' do
      it 'returns false' do
        expect(reference1 == 'not a reference').to be false
      end
    end
  end

  describe '#eql?' do
    it 'is aliased to ==' do
      ref1 = described_class.new(id: 'Body-123', digest_value: 'abc')
      ref2 = described_class.new(id: 'Body-123', digest_value: 'abc')

      expect(ref1.eql?(ref2)).to be true
    end
  end

  describe '#hash' do
    it 'returns the same hash for equal references' do
      ref1 = described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])
      ref2 = described_class.new(id: 'Body-123', digest_value: 'abc', inclusive_namespaces: ['soap'])

      expect(ref1.hash).to eq(ref2.hash)
    end

    it 'returns different hashes for different references' do
      ref1 = described_class.new(id: 'Body-123', digest_value: 'abc')
      ref2 = described_class.new(id: 'Body-456', digest_value: 'abc')

      expect(ref1.hash).not_to eq(ref2.hash)
    end

    it 'allows references to be used as hash keys' do
      ref1 = described_class.new(id: 'Body-123', digest_value: 'abc')
      ref2 = described_class.new(id: 'Body-123', digest_value: 'abc')

      hash = { ref1 => 'value' }
      expect(hash[ref2]).to eq('value')
    end
  end
end
