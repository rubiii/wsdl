# frozen_string_literal: true

module WSDL
  # Runtime configuration for {Client} and {Operation} instances.
  #
  # Controls request validation strictness and resource limits at
  # call time. Parse-time options (sandbox_paths, etc.) belong on
  # {WSDL.parse} instead.
  #
  # @example Create with defaults
  #   config = WSDL::Config.new
  #
  # @example Override specific settings
  #   config = WSDL::Config.new(strictness: { request_validation: false })
  #
  # @example Derive a modified copy
  #   relaxed = config.with(strictness: false)
  #
  class Config
    # @param strictness [Strictness, Hash, Boolean, nil] strictness settings.
    #   Accepts a Strictness object, a Hash of settings, +true+ (all strict),
    #   +false+ (all relaxed), or nil (defaults to all strict).
    # @param limits [Limits, nil] resource limits for request validation.
    #   If nil, uses {Limits} defaults.
    #
    def initialize(strictness: nil, limits: nil)
      @strictness = Strictness.resolve(strictness) || Strictness.new
      @limits = Limits.resolve(limits) || Limits.new

      freeze
    end

    # @return [Strictness] strictness settings for request validation
    attr_reader :strictness

    # @return [Limits] resource limits for request validation
    attr_reader :limits

    # Creates a new Config with some values changed.
    #
    # @param options [Hash] the settings to override
    # @option options [Strictness, Hash, Boolean] :strictness
    # @option options [Limits, nil] :limits
    # @return [Config] a new Config instance with the specified changes
    #
    # @example
    #   relaxed = config.with(strictness: false)
    #
    def with(**options)
      self.class.new(
        strictness: options.fetch(:strictness, @strictness),
        limits: options.fetch(:limits, @limits)
      )
    end

    # @return [Hash{Symbol => Object}] the config as a hash
    def to_h
      {
        strictness: @strictness,
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
  end
end
