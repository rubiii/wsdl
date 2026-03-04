# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Style/RedundantFetchBlock
# Our Cache#fetch requires a block - it doesn't support the two-argument form like Hash#fetch
RSpec.describe WSDL::Cache do
  describe '#fetch' do
    let(:cache) { described_class.new }

    it 'yields and caches the result on first call' do
      call_count = 0
      result = cache.fetch('key') {
        call_count += 1
        'value'
      }

      expect(result).to eq('value')
      expect(call_count).to eq(1)
    end

    it 'returns cached value on subsequent calls' do
      call_count = 0
      cache.fetch('key') do
        call_count += 1
        'value'
      end
      result = cache.fetch('key') {
        call_count += 1
        'other'
      }

      expect(result).to eq('value')
      expect(call_count).to eq(1)
    end

    it 'caches different keys separately' do
      cache.fetch('key1') do
        'value1'
      end
      cache.fetch('key2') do
        'value2'
      end

      expect(cache.fetch('key1') { 'other' }).to eq('value1')
      expect(cache.fetch('key2') { 'other' }).to eq('value2')
    end

    it 'treats URLs and file paths as-is' do
      cache.fetch('http://example.com/service?wsdl') do
        'remote'
      end
      cache.fetch('/path/to/file.wsdl') do
        'local'
      end

      expect(cache.fetch('http://example.com/service?wsdl') { 'other' }).to eq('remote')
      expect(cache.fetch('/path/to/file.wsdl') { 'other' }).to eq('local')
    end
  end

  describe '#fetch with TTL' do
    let(:cache) { described_class.new(ttl: 1) }

    it 'returns cached value before TTL expires' do
      cache.fetch('key') do
        'value'
      end

      expect(cache.fetch('key') { 'other' }).to eq('value')
    end

    it 'recomputes value after TTL expires' do
      cache.fetch('key') do
        'value'
      end

      # Simulate time passing
      allow(Time).to receive(:now).and_return(Time.now + 2)

      result = cache.fetch('key') { 'new_value' }
      expect(result).to eq('new_value')
    end
  end

  describe '#clear' do
    let(:cache) { described_class.new }

    it 'removes all entries from the cache' do
      cache.fetch('key1') do
        'value1'
      end
      cache.fetch('key2') do
        'value2'
      end

      cache.clear

      expect(cache.size).to eq(0)
      expect(cache.fetch('key1') { 'new' }).to eq('new')
    end
  end

  describe '#size' do
    let(:cache) { described_class.new }

    it 'returns 0 for empty cache' do
      expect(cache.size).to eq(0)
    end

    it 'returns the number of cached entries' do
      cache.fetch('key1') do
        'value1'
      end
      cache.fetch('key2') do
        'value2'
      end

      expect(cache.size).to eq(2)
    end
  end

  describe '#key?' do
    let(:cache) { described_class.new }

    it 'returns false for non-existent key' do
      expect(cache.key?('missing')).to be(false)
    end

    it 'returns true for existing key' do
      cache.fetch('present') do
        'value'
      end

      expect(cache.key?('present')).to be(true)
    end

    it 'returns false for expired key' do
      cache_with_ttl = described_class.new(ttl: 1)
      cache_with_ttl.fetch('key') do
        'value'
      end

      allow(Time).to receive(:now).and_return(Time.now + 2)

      expect(cache_with_ttl.key?('key')).to be(false)
    end
  end

  describe '#delete' do
    let(:cache) { described_class.new }

    it 'removes a specific entry and returns its value' do
      cache.fetch('key') do
        'value'
      end

      result = cache.delete('key')

      expect(result).to eq('value')
      expect(cache.key?('key')).to be(false)
    end

    it 'returns nil for non-existent key' do
      expect(cache.delete('missing')).to be_nil
    end
  end

  describe 'thread safety' do
    let(:cache) { described_class.new }

    it 'handles concurrent access without errors' do
      threads = 10.times.map { |i|
        Thread.new do
          100.times do |j|
            key = "key-#{i}-#{j % 10}"
            cache.fetch(key) { "value-#{i}-#{j}" }
          end
        end
      }

      expect { threads.each(&:join) }.not_to raise_error
    end

    it 'does not execute block multiple times for same key under contention' do
      call_count = 0
      mutex = Mutex.new

      threads = 10.times.map {
        Thread.new do
          cache.fetch('contested-key') do
            mutex.synchronize do
              call_count += 1
            end
            sleep 0.01 # Simulate slow operation
            'value'
          end
        end
      }

      threads.each(&:join)

      # The block should only be called once
      expect(call_count).to eq(1)
    end
  end
end
# rubocop:enable Style/RedundantFetchBlock
