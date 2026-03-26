# frozen_string_literal: true

module WSDL
  # Behavioral configuration for {Client} instances.
  #
  # Groups all parse-time and request-time settings into a single
  # frozen value object. Accepts the same keyword arguments as
  # {Client#initialize} for the behavioral subset (everything
  # except the WSDL source, HTTP client, and cache).
  #
  # @example Create with defaults
  #   config = WSDL::Config.new
  #
  # @example Override specific settings
  #   config = WSDL::Config.new(strictness: { schema_imports: false })
  #
  # @example Derive a modified copy
  #   relaxed = config.with(strictness: false)
  #
  class Config
    # @param strictness [Strictness, Hash, Boolean, nil] strictness settings.
    #   Accepts a Strictness object, a Hash of settings, +true+ (all strict),
    #   +false+ (all relaxed), or nil (uses {WSDL.strictness}).
    # @param strict_schema [Boolean, nil] **deprecated** — use +strictness:+ instead.
    #   +true+ maps to {Strictness.on}, +false+ to {Strictness.off}.
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed.
    #   When nil (default), sandbox is determined automatically based on WSDL source.
    # @param limits [Limits, nil] resource limits for DoS protection.
    #   If nil, uses {WSDL.limits}.
    #
    def initialize(strictness: nil, strict_schema: nil,
                   sandbox_paths: nil, limits: nil)
      @strictness = resolve_strictness(strictness, strict_schema)
      @sandbox_paths = sandbox_paths
      @limits = Limits.resolve(limits) || WSDL.limits

      freeze
    end

    # @return [Strictness] strictness settings for schema/request validation
    attr_reader :strictness

    # @return [Array<String>, nil] allowed directories for file access
    attr_reader :sandbox_paths

    # @return [Limits] resource limits for DoS protection
    attr_reader :limits

    # Creates a new Config with some values changed.
    #
    # @param options [Hash] the settings to override
    # @option options [Strictness, Hash, Boolean] :strictness
    # @option options [Boolean] :strict_schema **deprecated**
    # @option options [Array<String>, nil] :sandbox_paths
    # @option options [Limits, nil] :limits
    # @return [Config] a new Config instance with the specified changes
    #
    # @example
    #   relaxed = config.with(strictness: false)
    #
    def with(**options)
      self.class.new(
        strictness: options.fetch(:strictness, @strictness),
        strict_schema: options[:strict_schema],
        sandbox_paths: options.fetch(:sandbox_paths, @sandbox_paths),
        limits: options.fetch(:limits, @limits)
      )
    end

    # @return [Hash{Symbol => Object}] the config as a hash
    def to_h
      {
        strictness: @strictness,
        sandbox_paths: @sandbox_paths,
        limits: @limits
      }
    end

    # @param other [Object] the object to compare
    # @return [Boolean] true if equal
    def ==(other)
      return false unless other.is_a?(Config)

      to_h == other.to_h
    end

    alias eql? ==

    # @return [Integer] the hash code
    def hash
      to_h.hash
    end

    # @return [String] human-readable representation
    def inspect
      parts = to_h.map { |key, value| "#{key}=#{value.inspect}" }.join(' ')
      "#<#{self.class.name} #{parts}>"
    end

    private

    def resolve_strictness(strictness, strict_schema)
      resolved = Strictness.resolve(strictness)

      raise ArgumentError, 'Cannot specify both strictness: and strict_schema:' if resolved && !strict_schema.nil?

      return resolved || WSDL.strictness if strict_schema.nil?

      Kernel.warn '[WSDL] strict_schema is deprecated. ' \
                  "Use strictness: WSDL::Strictness.#{strict_schema ? 'on' : 'off'} instead.",
        uplevel: 2
      strict_schema ? Strictness.on : Strictness.off
    end
  end
end
