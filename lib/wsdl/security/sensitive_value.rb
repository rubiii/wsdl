# frozen_string_literal: true

module WSDL
  module Security
    # Wrapper for sensitive values that prevents accidental exposure in logs,
    # error messages, console output, or stack traces.
    #
    # @api private
    #
    class SensitiveValue
      REDACTED = '[REDACTED]'

      # @param value [Object] the sensitive value to protect
      def initialize(value)
        @value = value
      end

      # @return [Object] the wrapped sensitive value
      attr_reader :value

      # @return [String] a redacted representation
      def inspect
        "#<#{self.class.name} #{REDACTED}>"
      end

      # @return [String] the redacted placeholder
      def to_s
        REDACTED
      end

      # @param other [SensitiveValue, Object] the value to compare
      # @return [Boolean] true if the underlying values are equal
      def ==(other)
        @value == case other
        when SensitiveValue then other.value
        else other
        end
      end

      # @return [Boolean] true if the underlying value is nil
      def nil?
        @value.nil?
      end

      # @return [Boolean] true if the value is present
      def present?
        !@value.nil? && (!@value.respond_to?(:empty?) || !@value.empty?)
      end

      # @raise [SecurityError] always raises to prevent serialization
      def marshal_dump
        raise SecurityError, 'Cannot marshal sensitive values - this would expose secrets'
      end

      # @raise [SecurityError] always raises to prevent deserialization
      def marshal_load(_data)
        raise SecurityError, 'Cannot unmarshal sensitive values'
      end

      # @return [String] the redacted placeholder
      def to_json(*_args)
        REDACTED.to_json
      end

      # @return [String] the redacted placeholder
      def to_yaml(*_args)
        REDACTED.to_yaml
      end

      # @return [SensitiveValue] a new wrapper instance
      def dup
        self.class.new(@value)
      end

      # @return [SensitiveValue] a new wrapper with a duplicated value
      def clone(_freeze: nil)
        cloned_value = @value.respond_to?(:clone) ? @value.clone : @value
        self.class.new(cloned_value)
      end
    end
  end
end
