# frozen_string_literal: true

require 'digest'
require 'json'
require 'uri'

module WSDL
  module Parser
    # Loads parser results with cache-aware keying.
    #
    # This class centralizes parser cache key generation and cache access so
    # callers don't duplicate key-building logic.
    #
    # @api private
    #
    class CachedResult
      CACHE_KEY_VERSION = 4
      URL_PATTERN = /^https?:/i
      XML_PATTERN = /^</

      class << self
        # Loads a parser result, using cache when available.
        #
        # @param wsdl [String] WSDL location or inline XML
        # @param http [Object] HTTP adapter
        # @param cache [Cache, nil, Symbol] cache instance, nil, or :default
        # @param parse_options [Hash{Symbol => Object}] parse configuration
        # @option parse_options [Array<String>, nil] :sandbox_paths resolved sandbox paths
        # @option parse_options [Limits] :limits resource limits
        # @option parse_options [Boolean] :reject_doctype DOCTYPE policy
        # @option parse_options [Symbol] :schema_imports schema import failure policy
        # @return [Result] parsed WSDL result
        #
        def load(wsdl:, http:, cache:, parse_options:)
          sandbox_paths = parse_options.fetch(:sandbox_paths)
          limits = parse_options.fetch(:limits)
          reject_doctype = parse_options.fetch(:reject_doctype)
          schema_imports = parse_options.fetch(:schema_imports)

          cache = WSDL.cache if cache == :default
          return Result.new(wsdl, http, sandbox_paths:, limits:, reject_doctype:, schema_imports:) unless cache

          key = cache_key(
            wsdl:,
            sandbox_paths:,
            limits:,
            reject_doctype:,
            schema_imports:,
            http:
          )

          cache.fetch(key) do
            Result.new(wsdl, http, sandbox_paths:, limits:, reject_doctype:, schema_imports:)
          end
        end

        private

        # Builds the parser cache key.
        #
        # @param wsdl [String] WSDL location or inline XML
        # @param sandbox_paths [Array<String>, nil] resolved sandbox paths
        # @param limits [Limits] resource limits
        # @param reject_doctype [Boolean] DOCTYPE policy
        # @param schema_imports [Symbol] schema import failure policy
        # @param http [Object] HTTP adapter
        # @return [String] deterministic cache key
        #
        # rubocop:disable Metrics/ParameterLists
        def cache_key(wsdl:, sandbox_paths:, limits:, reject_doctype:, schema_imports:, http:)
          # rubocop:enable Metrics/ParameterLists
          payload = {
            version: CACHE_KEY_VERSION,
            source: normalize_source(wsdl),
            sandbox_paths: normalize_sandbox_paths(sandbox_paths),
            limits: normalize_limits(limits),
            reject_doctype: reject_doctype ? true : false,
            schema_imports: schema_imports.to_s,
            http_identity: normalize_http_identity(http)
          }

          "parser:#{Digest::SHA256.hexdigest(JSON.generate(payload))}"
        end

        # Normalizes WSDL source into a stable descriptor.
        #
        # @param wsdl [String] WSDL source
        # @return [Hash{Symbol => String}] normalized source descriptor
        #
        def normalize_source(wsdl)
          if wsdl.match?(XML_PATTERN)
            { type: 'inline', value: Digest::SHA256.hexdigest(wsdl) }
          elsif wsdl.match?(URL_PATTERN)
            { type: 'url', value: normalize_url(wsdl) }
          else
            { type: 'file', value: File.expand_path(wsdl) }
          end
        end

        # Normalizes URLs for stable cache identity.
        #
        # @param url [String] URL to normalize
        # @return [String] canonical URL
        #
        def normalize_url(url)
          URI.parse(url).normalize.to_s
        rescue URI::InvalidURIError
          url
        end

        # Normalizes sandbox paths to absolute, unique, sorted values.
        #
        # @param sandbox_paths [Array<String>, nil] sandbox paths
        # @return [Array<String>, nil] normalized sandbox paths
        #
        def normalize_sandbox_paths(sandbox_paths)
          return nil if sandbox_paths.nil?

          sandbox_paths.map { |path| File.expand_path(path) }.uniq.sort
        end

        # Normalizes limits to a stable hash.
        #
        # @param limits [Object] limits object
        # @return [Hash{String => Integer, nil}] normalized limits hash
        #
        def normalize_limits(limits)
          normalize_hash(limits.to_h)
        end

        # Normalizes HTTP adapter identity for cache partitioning.
        #
        # @param http [Object] HTTP adapter
        # @return [Hash{String => String}] adapter identity
        #
        def normalize_http_identity(http)
          {
            'strategy' => 'cache_key',
            'class' => http.class.name,
            'value' => http.cache_key.to_s
          }
        end

        # Converts a hash into a stable string-keyed representation.
        #
        # @param hash [Hash] input hash
        # @return [Hash{String => Object}] normalized hash
        #
        def normalize_hash(hash)
          hash.keys.sort_by(&:to_s).to_h { |key| [key.to_s, hash[key]] }
        end
      end
    end
  end
end
