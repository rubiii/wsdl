# frozen_string_literal: true

module WSDL
  # Immutable value object capturing the parse-affecting configuration
  # options that flow through the parse pipeline (Parser.parse → Importer).
  #
  # @!attribute [r] sandbox_paths
  #   @return [Array<String>, nil] directories where file access is allowed
  # @!attribute [r] limits
  #   @return [Limits] resource limits for DoS protection (always resolved, never nil)
  # @!attribute [r] strictness
  #   @return [Strictness] strictness settings for schema/request validation
  #
  ParseOptions = Data.define(:sandbox_paths, :limits, :strictness) {
    # Constructs a {ParseOptions} with sensible defaults.
    #
    # @param sandbox_paths [Array<String>, nil] sandbox paths (default: `nil`, auto-resolved by Source)
    # @param limits [Limits, nil] resource limits (default: {WSDL.limits})
    # @param strictness [Strictness, nil] strictness settings (default: {WSDL.strictness})
    # @return [ParseOptions]
    #
    def self.default(sandbox_paths: nil, limits: nil, strictness: nil)
      new(
        sandbox_paths:,
        limits: limits || WSDL.limits,
        strictness: strictness || WSDL.strictness
      )
    end
  }
end
