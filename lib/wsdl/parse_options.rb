# frozen_string_literal: true

module WSDL
  # Immutable value object capturing the parse-affecting configuration
  # options that flow through the parse pipeline (Client → CachedResult →
  # Result → Importer).
  #
  # @!attribute [r] sandbox_paths
  #   @return [Array<String>, nil, Symbol] directories where file access is allowed
  # @!attribute [r] limits
  #   @return [Limits] resource limits for DoS protection (always resolved, never nil)
  # @!attribute [r] strict_schema
  #   @return [Boolean] strict schema handling and request validation mode
  #
  ParseOptions = Data.define(:sandbox_paths, :limits, :strict_schema) {
    # Constructs a {ParseOptions} with sensible defaults.
    #
    # @param sandbox_paths [Array<String>, nil, Symbol] sandbox paths (default: `:auto`)
    # @param limits [Limits, nil] resource limits (default: {WSDL.limits})
    # @param strict_schema [Boolean] strict schema mode (default: `true`)
    # @return [ParseOptions]
    #
    def self.default(sandbox_paths: :auto, limits: nil, strict_schema: true)
      new(
        sandbox_paths: sandbox_paths,
        limits: limits || WSDL.limits,
        strict_schema: strict_schema ? true : false
      )
    end
  }
end
