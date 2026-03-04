# frozen_string_literal: true

require 'digest'
require 'json'

module WSDL
  module Parser
    # Loads parser results with cache-aware keying.
    #
    # Cache key correctness is enforced by {ParseOptions}, the immutable value
    # object that captures **every** parse-affecting option. Both the cache key
    # and {Result.parse} receive the same {ParseOptions} instance (via
    # {ParseInputs}), so they can never diverge.
    #
    # Adding a new parse-affecting parameter requires two steps:
    #
    # 1. Add the member to {ParseOptions} (`lib/wsdl/parse_options.rb`).
    # 2. Add its normalization to {.cache_key} in this file.
    #
    # @api private
    #
    class CachedResult
      # Cache key schema version.
      #
      # Bump this when the key *format* changes (e.g. new normalization
      # logic). Adding a new member to {ParseOptions} also warrants a bump
      # so that entries cached by an older version are not reused.
      #
      # @return [Integer]
      CACHE_KEY_VERSION = 9

      # Every input that affects parser output.
      #
      # This is the **single source of truth** for cache key generation.
      # Both {.cache_key} and {.build_result} consume the same instance,
      # making it impossible for them to see different inputs.
      #
      # @!attribute [r] wsdl
      #   @return [String] WSDL location (HTTP(S) URL or local file path)
      # @!attribute [r] http
      #   @return [Object] HTTP adapter instance
      # @!attribute [r] parse_options
      #   @return [ParseOptions] parse configuration options
      #
      ParseInputs = Data.define(:wsdl, :http, :parse_options)

      class << self
        # Loads a parser result, using cache when available.
        #
        # @param wsdl [String] WSDL location (HTTP(S) URL or local file path)
        # @param http [Object] HTTP adapter
        # @param cache [Cache, nil, Symbol] cache instance, nil, or :default
        # @param parse_options [ParseOptions] parse configuration options
        # @return [Result] parsed WSDL result
        #
        def load(wsdl:, http:, cache:, parse_options:)
          inputs = ParseInputs.new(wsdl:, http:, parse_options:)

          cache = WSDL.cache if cache == :default
          return build_result(inputs) unless cache

          cache.fetch(cache_key(inputs)) { build_result(inputs) }
        end

        private

        # Constructs a {Result} from the given parse inputs.
        #
        # @param inputs [ParseInputs]
        # @return [Result]
        #
        def build_result(inputs)
          Result.parse(inputs.wsdl, inputs.http, inputs.parse_options)
        end

        # Derives a deterministic cache key from the given parse inputs.
        #
        # Every member of {ParseInputs} must be represented in the payload.
        # When adding a member, add its normalized form here and bump
        # {CACHE_KEY_VERSION}.
        #
        # @param inputs [ParseInputs]
        # @return [String] deterministic cache key
        #
        def cache_key(inputs)
          opts = inputs.parse_options
          payload = {
            version: CACHE_KEY_VERSION,
            source: normalize_source(inputs.wsdl),
            sandbox_paths: normalize_sandbox_paths(opts.sandbox_paths),
            limits: normalize_limits(opts.limits),
            reject_doctype: opts.reject_doctype ? true : false,
            strict_schema: opts.strict_schema ? true : false,
            http_identity: normalize_http_identity(inputs.http)
          }

          "parser:#{Digest::SHA256.hexdigest(JSON.generate(payload))}"
        end

        # Normalizes WSDL source into a stable descriptor.
        #
        # @param wsdl [String] WSDL source
        # @return [Hash{Symbol => String}] normalized source descriptor
        #
        def normalize_source(wsdl)
          source = Source.validate_wsdl!(wsdl)
          return { type: 'url', value: source.normalized_url } if source.url?

          { type: 'file', value: source.expanded_file_path }
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
