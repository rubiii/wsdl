# frozen_string_literal: true

require 'digest'

class WSDL
  # Thread-safe in-memory cache for parsed WSDL definitions.
  #
  # This cache is designed to avoid redundant HTTP requests and parsing
  # when working with WSDL documents, especially in multithreaded environments.
  #
  # @example Basic usage with default settings
  #   cache = WSDL::Cache.new
  #   value = cache.fetch('http://example.com/service?wsdl') { expensive_operation }
  #
  # @example With TTL (time-to-live)
  #   cache = WSDL::Cache.new(ttl: 3600)  # 1 hour TTL
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
    def initialize(ttl: nil)
      @store = {}
      @ttl = ttl
      @mutex = Mutex.new
    end

    # Fetches a value from the cache, or computes and stores it if not present.
    #
    # If the key exists and hasn't expired, returns the cached value.
    # Otherwise, yields to the block, stores the result, and returns it.
    #
    # @param key [String] the cache key (typically a URL or file path)
    # @yield computes the value if not cached
    # @yieldreturn [Object] the value to cache
    # @return [Object] the cached or computed value
    def fetch(key)
      # Normalize the key (handle inline XML by hashing)
      normalized_key = normalize_key(key)

      @mutex.synchronize do
        entry = @store[normalized_key]

        if entry && !expired?(entry)
          entry[:value]
        else
          value = yield
          @store[normalized_key] = { value:, timestamp: Time.now }
          value
        end
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
      normalized_key = normalize_key(key)

      @mutex.synchronize do
        entry = @store[normalized_key]
        !!(entry && !expired?(entry))
      end
    end

    # Removes a specific entry from the cache.
    #
    # @param key [String] the cache key to remove
    # @return [Object, nil] the removed value, or nil if not found
    def delete(key)
      normalized_key = normalize_key(key)

      @mutex.synchronize do
        entry = @store.delete(normalized_key)
        entry&.fetch(:value)
      end
    end

    private

    # Normalizes a cache key.
    #
    # For inline XML (strings starting with '<'), generates a SHA256 hash
    # to create a stable, reasonable-length key.
    # For URLs and file paths, returns the key as-is.
    #
    # @param key [String] the original key
    # @return [String] the normalized key
    def normalize_key(key)
      if key.start_with?('<')
        "inline:#{Digest::SHA256.hexdigest(key)}"
      else
        key
      end
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
