# frozen_string_literal: true

require 'spec_helper'
require 'wsdl/security/secure_compare'

RSpec.describe WSDL::Security::SecureCompare do
  describe '.equal?' do
    context 'with identical strings' do
      it 'returns true' do
        expect(described_class.equal?('abc123', 'abc123')).to be true
      end

      it 'returns true for empty strings' do
        expect(described_class.equal?('', '')).to be true
      end

      it 'returns true for long identical strings' do
        long_string = 'a' * 10_000
        expect(described_class.equal?(long_string, long_string.dup)).to be true
      end
    end

    context 'with different strings' do
      it 'returns false for strings of same length' do
        expect(described_class.equal?('abc123', 'xyz789')).to be false
      end

      it 'returns false for strings differing at the start' do
        expect(described_class.equal?('Xbc123', 'abc123')).to be false
      end

      it 'returns false for strings differing at the end' do
        expect(described_class.equal?('abc123', 'abc12X')).to be false
      end

      it 'returns false for strings of different lengths' do
        expect(described_class.equal?('short', 'longer_string')).to be false
      end

      it 'returns false for empty vs non-empty string' do
        expect(described_class.equal?('', 'abc')).to be false
      end
    end

    context 'with non-string arguments' do
      it 'returns false for nil first argument' do
        expect(described_class.equal?(nil, 'abc')).to be false
      end

      it 'returns false for nil second argument' do
        expect(described_class.equal?('abc', nil)).to be false
      end

      it 'returns false for both nil arguments' do
        expect(described_class.equal?(nil, nil)).to be false
      end

      it 'returns false for integer arguments' do
        expect(described_class.equal?(123, 123)).to be false
      end

      it 'returns false for symbol arguments' do
        expect(described_class.equal?(:abc, :abc)).to be false
      end

      it 'returns false for mixed string and symbol' do
        expect(described_class.equal?('abc', :abc)).to be false
      end
    end

    context 'with Base64-encoded digests' do
      it 'compares SHA-256 Base64 digests correctly' do
        # SHA-256 digests encoded in Base64 are 44 characters
        digest1 = 'n4bQgYhMfWWaL28WTBnkQyJY6jQGYxLH2mWl7V7ALz0='
        digest2 = 'n4bQgYhMfWWaL28WTBnkQyJY6jQGYxLH2mWl7V7ALz0='
        expect(described_class.equal?(digest1, digest2)).to be true
      end

      it 'detects different SHA-256 digests' do
        digest1 = 'n4bQgYhMfWWaL28WTBnkQyJY6jQGYxLH2mWl7V7ALz0='
        digest2 = 'XYZQgYhMfWWaL28WTBnkQyJY6jQGYxLH2mWl7V7ALz0='
        expect(described_class.equal?(digest1, digest2)).to be false
      end
    end

    context 'with binary strings' do
      it 'compares binary strings correctly' do
        binary1 = "\x00\x01\x02\x03".b
        binary2 = "\x00\x01\x02\x03".b
        expect(described_class.equal?(binary1, binary2)).to be true
      end

      it 'detects different binary strings' do
        binary1 = "\x00\x01\x02\x03".b
        binary2 = "\x00\x01\x02\xFF".b
        expect(described_class.equal?(binary1, binary2)).to be false
      end
    end

    context 'with unicode strings' do
      it 'compares unicode strings correctly' do
        expect(described_class.equal?('héllo wörld', 'héllo wörld')).to be true
      end

      it 'detects different unicode strings' do
        expect(described_class.equal?('héllo', 'hello')).to be false
      end
    end
  end
end
