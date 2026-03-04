# frozen_string_literal: true

require 'digest'
require 'json'

module WSDL
  module Parser
    # Loads parser results with cache-aware keying.
    #
    # Cache key correctness is enforced by {ParseInputs}, a frozen Data class
    # that captures **every** input affecting parse output. Both the cache key
    # and the {Result} constructor receive the same {ParseInputs} instance, so
    # they can never diverge.
    #
    # Adding a new parse-affecting parameter requires three steps — all in
    # this file:
    #
    # 1. Add the member to {ParseInputs}.
    # 2. Add its normalization to {.cache_key}.
    # 3. Pass it through in {CachedResult.build_result}.
    #
    # Because `Data.define` requires every member at construction time,
    # forgetting step 1 raises `ArgumentError` immediately.
    #
    # @api private
    #
    class CachedResult
      # Cache key schema version.
      #
      # Bump this when the key *format* changes (e.g. new normalization
      # logic). Adding a new member to {ParseInputs} also warrants a bump
      # so that entries cached by an older version are not reused.
      #
      # @return [Integer]
      CACHE_KEY_VERSION = 8

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
      # @!attribute [r] sandbox_paths
      #   @return [Array<String>, nil] resolved sandbox paths
      # @!attribute [r] limits
      #   @return [Limits] resource limits
      # @!attribute [r] reject_doctype
      #   @return [Boolean] DOCTYPE policy
      # @!attribute [r] strict_schema
      #   @return [Boolean] strict schema handling mode
      #
      ParseInputs = Data.define(:wsdl, :http, :sandbox_paths, :limits, :reject_doctype, :strict_schema)

      class << self
        # Loads a parser result, using cache when available.
        #
        # @param wsdl [String] WSDL location (HTTP(S) URL or local file path)
        # @param http [Object] HTTP adapter
        # @param cache [Cache, nil, Symbol] cache instance, nil, or :default
        # @param sandbox_paths [Array<String>, nil] resolved sandbox paths
        # @param limits [Limits] resource limits
        # @param reject_doctype [Boolean] DOCTYPE policy
        # @param strict_schema [Boolean] strict schema handling mode
        # @return [Result] parsed WSDL result
        #
        # rubocop:disable Metrics/ParameterLists
        def load(wsdl:, http:, cache:, sandbox_paths:, limits:, reject_doctype:, strict_schema:)
          # rubocop:enable Metrics/ParameterLists
          inputs = ParseInputs.new(wsdl:, http:, sandbox_paths:, limits:, reject_doctype:, strict_schema:)

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
          Result.new(
            inputs.wsdl,
            inputs.http,
            sandbox_paths: inputs.sandbox_paths,
            limits: inputs.limits,
            reject_doctype: inputs.reject_doctype,
            strict_schema: inputs.strict_schema
          )
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
          payload = {
            version: CACHE_KEY_VERSION,
            source: normalize_source(inputs.wsdl),
            sandbox_paths: normalize_sandbox_paths(inputs.sandbox_paths),
            limits: normalize_limits(inputs.limits),
            reject_doctype: inputs.reject_doctype ? true : false,
            strict_schema: inputs.strict_schema ? true : false,
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
