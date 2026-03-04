# frozen_string_literal: true

module WSDL
  module Security
    # Immutable response-side security policy.
    #
    # This policy controls whether response verification is enforced.
    class ResponsePolicy
      # Do not enforce response signature validation on call.
      MODE_DISABLED = :disabled

      # Verify response only if a signature is present.
      MODE_IF_PRESENT = :if_present

      # Require a valid signature on every response.
      MODE_REQUIRED = :required

      # Allowed response verification modes.
      #
      # @return [Array<Symbol>]
      MODES = [MODE_DISABLED, MODE_IF_PRESENT, MODE_REQUIRED].freeze

      # Creates the default response policy.
      #
      # @return [ResponsePolicy]
      #
      def self.default
        new(mode: MODE_DISABLED, options: ResponseVerification::Options.default)
      end

      # @param mode [Symbol] one of {MODES}
      # @param options [ResponseVerification::Options]
      def initialize(mode:, options:)
        validate_mode!(mode)

        @mode = mode
        @options = options
        freeze
      end

      # @return [Symbol]
      attr_reader :mode

      # @return [ResponseVerification::Options]
      attr_reader :options

      # @param mode [Symbol]
      # @return [ResponsePolicy]
      def with_mode(mode)
        self.class.new(mode:, options: @options)
      end

      # @param options [ResponseVerification::Options]
      # @return [ResponsePolicy]
      def with_options(options)
        self.class.new(mode: @mode, options:)
      end

      # @return [Boolean]
      def disabled?
        @mode == MODE_DISABLED
      end

      # @return [Boolean]
      def verify_if_present?
        @mode == MODE_IF_PRESENT
      end

      # @return [Boolean]
      def required?
        @mode == MODE_REQUIRED
      end

      # Enforces response verification according to this policy's mode.
      #
      # @param response [WSDL::Response]
      # @return [void]
      # @raise [WSDL::SignatureVerificationError] when verification fails or
      #   is required but no signature is present
      def enforce!(response)
        case @mode
        when MODE_DISABLED
          nil
        when MODE_IF_PRESENT
          response.security.verify! if response.security.signature_present?
        when MODE_REQUIRED
          response.security.verify!
        end
      end

      private

      def validate_mode!(mode)
        return if MODES.include?(mode)

        raise ArgumentError, "Invalid response verification mode: #{mode.inspect}. " \
                             "Expected one of: #{MODES.map(&:inspect).join(', ')}"
      end
    end
  end
end
