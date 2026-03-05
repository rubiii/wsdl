# frozen_string_literal: true

module WSDL
  # Behavioral configuration for {Client} instances.
  #
  # Groups all parse-time and request-time settings into a single
  # frozen value object. Accepts the same keyword arguments as
  # {Client#initialize} for the behavioral subset (everything
  # except the WSDL source, HTTP adapter, and cache).
  #
  # @example Create with defaults
  #   config = WSDL::Config.new
  #
  # @example Override specific settings
  #   config = WSDL::Config.new(format_xml: false, strict_schema: false)
  #
  # @example Derive a modified copy
  #   relaxed = config.with(strict_schema: false)
  #
  class Config
    # @param format_xml [Boolean] whether to format XML output with indentation.
    #   Set to `false` for whitespace-sensitive SOAP servers. Defaults to `true`.
    # @param strict_schema [Boolean] strict schema handling and request validation mode.
    #   - `true` (default) enables strict schema imports and strict request validation
    #   - `false` enables best-effort schema imports and relaxed request validation
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed.
    #   When nil (default), sandbox is determined automatically based on WSDL source:
    #   - URL source -> file access disabled (all imports must use URLs)
    #   - File source -> sandboxed to the WSDL's parent directory
    #   When provided, overrides the automatic sandbox with the specified directories.
    # @param limits [Limits, nil] resource limits for DoS protection.
    #   If nil, uses {WSDL.limits}. Use a custom Limits instance to increase
    #   limits for specific WSDLs that exceed defaults.
    #
    def initialize(format_xml: true, strict_schema: true,
                   sandbox_paths: nil, limits: nil)
      @format_xml = format_xml
      @strict_schema = strict_schema ? true : false
      @sandbox_paths = sandbox_paths
      @limits = limits || WSDL.limits

      freeze
    end

    # @return [Boolean] whether to format XML output with indentation
    attr_reader :format_xml

    # @return [Boolean] strict schema handling and request validation mode
    attr_reader :strict_schema

    # @return [Array<String>, nil] allowed directories for file access
    attr_reader :sandbox_paths

    # @return [Limits] resource limits for DoS protection
    attr_reader :limits

    # Creates a new Config with some values changed.
    #
    # @param options [Hash] the settings to override
    # @option options [Boolean] :format_xml
    # @option options [Boolean] :strict_schema
    # @option options [Array<String>, nil] :sandbox_paths
    # @option options [Limits, nil] :limits
    # @return [Config] a new Config instance with the specified changes
    #
    # @example
    #   relaxed = config.with(strict_schema: false)
    #
    def with(**options)
      self.class.new(
        format_xml: options.fetch(:format_xml, @format_xml),
        strict_schema: options.fetch(:strict_schema, @strict_schema),
        sandbox_paths: options.fetch(:sandbox_paths, @sandbox_paths),
        limits: options.fetch(:limits, @limits)
      )
    end

    # @return [Hash{Symbol => Object}] the config as a hash
    def to_h
      {
        format_xml: @format_xml,
        strict_schema: @strict_schema,
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
  end
end
