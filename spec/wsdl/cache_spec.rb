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

    it 'returns cached value on subsequent calls without yielding' do
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

    it 'returns the same value regardless of which concurrent thread wins' do
      # Double-checked locking means two threads may compute simultaneously,
      # but all callers receive a consistent value for the same key.
      results = []
      mutex = Mutex.new

      threads = 5.times.map {
        Thread.new do
          val = cache.fetch('key') {
            sleep 0.01
            'consistent'
          }
          mutex.synchronize { results << val }
        end
      }

      threads.each(&:join)
      expect(results.uniq).to eq(['consistent'])
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

    it 'stores the recomputed value after expiry' do
      cache.fetch('key') do
        'original'
      end

      future = Time.now + 2
      allow(Time).to receive(:now).and_return(future)

      cache.fetch('key') do
        'refreshed'
      end

      expect(cache.fetch('key') { 'should_not_run' }).to eq('refreshed')
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

    it 'does not hold the global lock during block execution' do
      # Verify that concurrent fetches for DIFFERENT keys are not serialized.
      # If the lock were held during yield, these would execute sequentially
      # (~0.5s total). With double-checked locking they run in parallel (~0.1s).
      start = Time.now

      threads = 5.times.map { |i|
        Thread.new do
          cache.fetch("key-#{i}") do
            sleep 0.1
            "value-#{i}"
          end
        end
      }

      threads.each(&:join)
      elapsed = Time.now - start

      # With parallel execution this should complete in ~0.1s, not ~0.5s.
      # Use a generous threshold to avoid flaky tests.
      expect(elapsed).to be < 0.4
    end

    it 'keeps the first value when concurrent threads compute the same key' do
      # Under double-checked locking, multiple threads may compute simultaneously
      # for the same uncached key, but the first result stored wins.
      results = []
      mutex = Mutex.new

      threads = 10.times.map {
        Thread.new do
          val = cache.fetch('contested-key') {
            sleep 0.01
            'value'
          }
          mutex.synchronize { results << val }
        end
      }

      threads.each(&:join)

      # All threads must see the same cached value
      expect(results).to all(eq('value'))
      expect(cache.size).to eq(1)
    end

    it 'never returns nil for a key that has been computed' do
      results = []
      mutex = Mutex.new

      threads = 20.times.map {
        Thread.new do
          val = cache.fetch('key') {
            sleep 0.005
            'non-nil-value'
          }
          mutex.synchronize { results << val }
        end
      }

      threads.each(&:join)

      expect(results).to all(eq('non-nil-value'))
    end
  end

  describe 'double-checked locking correctness' do
    let(:cache) { described_class.new }

    it 'uses the earlier value when another thread populates the entry during computation' do
      # Simulate the race: thread A starts computing, thread B finishes first.
      # Thread A's result should be discarded in favor of thread B's earlier entry.
      barrier = Queue.new

      thread_a = Thread.new do
        cache.fetch('race-key') do
          barrier.pop # wait for thread B to finish
          'late-value'
        end
      end

      thread_b = Thread.new do
        # Give thread A a moment to enter fetch and release the lock
        sleep 0.02
        cache.fetch('race-key') do
          'early-value'
        end
        barrier.push(:done) # signal thread A to continue
      end

      thread_b.join
      thread_a.join

      # Thread B's value was stored first, so the cache should keep it
      expect(cache.fetch('race-key') { 'should-not-run' }).to eq('early-value')
    end

    it 'does not yield when the fast path hits' do
      cache.fetch('warm') do
        'cached'
      end

      yielded = false
      cache.fetch('warm') do
        yielded = true
        'should-not-run'
      end

      expect(yielded).to be(false)
    end

    it 'propagates exceptions from the block without caching' do
      expect {
        cache.fetch('error-key') { raise 'boom' }
      }.to raise_error(RuntimeError, 'boom')

      expect(cache.key?('error-key')).to be(false)

      # Subsequent fetch should retry and succeed
      result = cache.fetch('error-key') { 'recovered' }
      expect(result).to eq('recovered')
    end
  end
end
# rubocop:enable Style/RedundantFetchBlock
