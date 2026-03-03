# frozen_string_literal: true

module WSDL
  module Request
    # XML name validation helpers used by the request DSL.
    module Names
      # XML NCName validation pattern.
      #
      # @return [Regexp]
      NCNAME_PATTERN = /\A[_\p{L}][\p{L}\p{N}_.-]*\z/u

      # Prefixes predeclared by the DSL and protected from override.
      #
      # @return [Array<String>]
      RESERVED_PREFIXES = %w[wsse wsu ds ec env soap soap12 xsi].freeze

      module_function

      def valid_ncname?(value)
        return false if value.nil?

        text = value.to_s
        return false if text.empty?

        text.match?(NCNAME_PATTERN)
      end

      def validate_ncname!(value, kind: 'name')
        return if valid_ncname?(value)

        raise RequestDslError, "Invalid XML #{kind} #{value.inspect}: expected NCName"
      end

      # Returns [prefix, local_name]. Prefix may be nil.
      def parse_qname(value)
        text = value.to_s
        if text.include?(':')
          prefix, local = text.split(':', 2)
          [prefix, local]
        else
          [nil, text]
        end
      end

      # Validates that a value is either an NCName or QName.
      #
      # @param value [#to_s]
      # @return [void]
      # @raise [RequestDslError] when the value is not a valid QName
      def validate_qname!(value)
        prefix, local = parse_qname(value)

        validate_ncname!(local, kind: 'local name')
        return if prefix.nil?

        validate_ncname!(prefix, kind: 'prefix')
      end

      def validate_prefix_override!(prefix)
        return unless RESERVED_PREFIXES.include?(prefix)

        raise RequestDslError, "Namespace prefix #{prefix.inspect} is reserved and cannot be overridden"
      end
    end
  end
end
