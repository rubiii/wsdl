# frozen_string_literal: true

module WSDL
  # Thread-safe in-memory LRU cache for parsed WSDL definitions.
  #
  # This cache is designed to avoid redundant HTTP requests and parsing
  # when working with WSDL documents, especially in multithreaded environments.
  # When a +max_entries+ limit is set, the least recently used entry is
  # evicted to make room for new ones.
  #
  # Uses double-checked locking so the global mutex is never held while the
  # block executes. Concurrent requests for *different* keys compute in
  # parallel. Under contention for the *same* uncached key, duplicate
  # computation may occur but only the first result is stored — the block
  # must be idempotent.
  #
  # @example Basic usage with default settings
  #   cache = WSDL::Cache.new
  #   value = cache.fetch('http://example.com/service?wsdl') { expensive_operation }
  #
  # @example With TTL (time-to-live)
  #   cache = WSDL::Cache.new(ttl: 3600)  # 1 hour TTL
  #
  # @example With max entries to prevent unbounded memory growth
  #   cache = WSDL::Cache.new(max_entries: 100)
  #
  # @example Custom cache implementation for Redis
  #   class RedisCache
  #     def initialize(redis, ttl: nil)
  #       @redis = redis
  #       @ttl = ttl
  #     end
  #
  #     def fetch(key)
  #       cached = @redis.get(key)
  #       return Marshal.load(cached) if cached
  #
  #       value = yield
  #       @redis.set(key, Marshal.dump(value), ex: @ttl)
  #       value
  #     end
  #
  #     def clear
  #       @redis.flushdb
  #     end
  #   end
  #
  #   WSDL.cache = RedisCache.new(Redis.new, ttl: 3600)
  #
  class Cache
    # Creates a new Cache instance.
    #
    # @param ttl [Integer, nil] optional time-to-live in seconds for cached entries.
    #   When nil (default), entries never expire.
    # @param max_entries [Integer, nil] optional maximum number of entries to store.
    #   When the limit is reached, the least recently used (LRU) entry is evicted.
    #   When nil (default), the cache can grow without bound.
    def initialize(ttl: nil, max_entries: nil)
      @store = {}
      @ttl = ttl
      @max_entries = max_entries
      @mutex = Mutex.new
    end

    # Fetches a value from the cache, or computes and stores it if not present.
    #
    # If the key exists and hasn't expired, returns the cached value.
    # Otherwise, yields to the block **outside the lock**, stores the result,
    # and returns it. A second lock acquisition double-checks that another
    # thread hasn't populated the entry in the meantime.
    #
    # @param key [String] the cache key (typically a URL or file path)
    # @yield computes the value if not cached
    # @yieldreturn [Object] the value to cache
    # @return [Object] the cached or computed value
    def fetch(key)
      # Fast path — return a cached, non-expired entry.
      @mutex.synchronize do
        entry = promote!(key)
        return entry[:value] if entry
      end

      # Compute outside the lock so concurrent misses for different keys
      # are not serialized against each other.
      value = yield

      # Store the result.  Double-check: if another thread populated
      # the entry while we were computing, keep the earlier value.
      @mutex.synchronize do
        entry = promote!(key)
        return entry[:value] if entry

        @store[key] = { value:, timestamp: Time.now }
        evict_lru! if @max_entries && @store.size > @max_entries
        value
      end
    end

    # Removes all entries from the cache.
    #
    # @return [void]
    def clear
      @mutex.synchronize do
        @store.clear
      end
    end

    # Returns the number of entries in the cache.
    #
    # @return [Integer] the number of cached entries
    def size
      @mutex.synchronize do
        @store.size
      end
    end

    # Checks if a key exists in the cache and hasn't expired.
    #
    # @param key [String] the cache key
    # @return [Boolean] true if the key exists and is valid
    def key?(key)
      @mutex.synchronize do
        entry = @store[key]
        !!(entry && !expired?(entry))
      end
    end

    # Removes a specific entry from the cache.
    #
    # @param key [String] the cache key to remove
    # @return [Object, nil] the removed value, or nil if not found
    def delete(key)
      @mutex.synchronize do
        entry = @store.delete(key)
        entry&.fetch(:value)
      end
    end

    private

    # Promotes a key to most-recently-used by deleting and reinserting it.
    # Returns the entry hash on hit, or nil on miss/expiry.
    # Assumes the mutex is already held by the caller.
    #
    # @param key [String] the cache key
    # @return [Hash, nil] the cache entry, or nil
    def promote!(key)
      entry = @store.delete(key)
      return unless entry && !expired?(entry)

      @store[key] = entry
    end

    # Evicts the least recently used entry from the cache.
    # Assumes the mutex is already held by the caller.
    #
    # @return [void]
    def evict_lru!
      @store.delete(@store.each_key.first)
    end

    # Checks if a cache entry has expired.
    #
    # @param entry [Hash] the cache entry with :timestamp
    # @return [Boolean] true if the entry has expired
    def expired?(entry)
      return false if @ttl.nil?

      Time.now - entry[:timestamp] > @ttl
    end
  end
end
