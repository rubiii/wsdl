# frozen_string_literal: true

require 'base64'
require 'bigdecimal'
require 'date'
require 'time'

module WSDL
  class Response
    # Coerces XML text values into Ruby values based on XSD types.
    #
    # @api private
    class TypeCoercer
      include Log

      # XSD simple types mapped to string coercion.
      #
      # Includes primitive string types, Gregorian date fragments (which can
      # have timezone suffixes that would be lost if converted), duration
      # (no stdlib Ruby type), and meta-types (anyType, anySimpleType).
      #
      # @return [Array<String>]
      STRING_TYPES = %w[
        string normalizedString token language Name NCName ID IDREF ENTITY NMTOKEN anyURI QName
        duration gYear gYearMonth gMonthDay gDay gMonth NOTATION anyType anySimpleType
      ].freeze

      # XSD list types mapped to whitespace-split coercion.
      #
      # Per XSD Part 2 §3.3.1, these are lists of the singular form
      # (IDREF, ENTITY, NMTOKEN) separated by whitespace.
      #
      # @return [Array<String>]
      LIST_TYPES = %w[IDREFS ENTITIES NMTOKENS].freeze

      # XSD simple types mapped to integer coercion.
      #
      # @return [Array<String>]
      INTEGER_TYPES = %w[
        integer int long short byte
        nonNegativeInteger positiveInteger nonPositiveInteger negativeInteger
        unsignedLong unsignedInt unsignedShort unsignedByte
      ].freeze

      # Maps XSD local type names to coercion groups.
      #
      # @return [Hash{String => Symbol}]
      TYPE_GROUPS = begin
        groups = {}
        STRING_TYPES.each do |type|
          groups[type] = :string
        end
        LIST_TYPES.each do |type|
          groups[type] = :list
        end
        INTEGER_TYPES.each do |type|
          groups[type] = :integer
        end
        groups['decimal'] = :decimal
        groups['float'] = :float
        groups['double'] = :float
        groups['boolean'] = :boolean
        groups['date'] = :date
        groups['dateTime'] = :datetime
        groups['time'] = :time
        groups['base64Binary'] = :base64
        groups['hexBinary'] = :hex_binary
        groups.freeze
      end

      # Group-to-handler map used by {.coerce}.
      #
      # @return [Hash{Symbol => Proc}]
      GROUP_HANDLERS = {
        string: ->(value) { convert_string(value) },
        integer: ->(value) { convert_integer(value) },
        decimal: ->(value) { convert_decimal(value) },
        float: ->(value) { convert_float(value) },
        boolean: ->(value) { convert_boolean(value) },
        date: ->(value) { convert_date(value) },
        datetime: ->(value) { convert_datetime(value) },
        time: ->(value) { convert_time(value) },
        base64: ->(value) { convert_base64(value) },
        hex_binary: ->(value) { convert_hex_binary(value) },
        list: ->(value) { convert_list(value) }
      }.freeze

      # Matches ISO8601 timezone suffixes accepted for XSD dateTime/time parsing.
      #
      # @return [Regexp]
      TIMEZONE_SUFFIX = /(Z|[+-](?:0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)\z/

      class << self
        # Coerces a text value based on its XSD type.
        #
        # @param value [String] the value to coerce
        # @param type [String, nil] the XSD type name, e.g. 'xsd:int'
        # @return [Object] the coerced value, or the original string when coercion fails
        def coerce(value, type)
          return value if value.nil? || value.empty?

          local_type = type&.split(':')&.last
          group = TYPE_GROUPS[local_type]
          handler = GROUP_HANDLERS[group]
          return value unless handler

          handler.call(value)
        end

        private

        def convert_string(value)
          value.to_s
        end

        def convert_integer(value)
          Integer(value)
        rescue ArgumentError
          coercion_fallback(value, 'integer')
        end

        def convert_decimal(value)
          BigDecimal(value)
        rescue ArgumentError
          coercion_fallback(value, 'decimal')
        end

        def convert_float(value)
          Float(value)
        rescue ArgumentError
          coercion_fallback(value, 'float')
        end

        def convert_boolean(value)
          return true if %w[true 1].include?(value)
          return false if %w[false 0].include?(value)

          coercion_fallback(value, 'boolean')
        end

        def convert_date(value)
          Date.iso8601(value)
        rescue ArgumentError
          coercion_fallback(value, 'date')
        end

        def convert_datetime(value)
          # Per XSD, timezone is optional; preserve lexical form when absent.
          return value unless explicit_timezone?(value)

          Time.xmlschema(value)
        rescue ArgumentError
          coercion_fallback(value, 'dateTime')
        end

        def convert_time(value)
          # Per XSD, timezone is optional; preserve lexical form when absent.
          return value unless explicit_timezone?(value)

          Time.xmlschema("1970-01-01T#{value}")
        rescue ArgumentError
          coercion_fallback(value, 'time')
        end

        def convert_base64(value)
          Base64.decode64(value)
        end

        def convert_list(value)
          value.split
        end

        def convert_hex_binary(value)
          return value unless value.length.even? && value.match?(/\A[0-9a-fA-F]+\z/)

          [value].pack('H*')
        end

        def explicit_timezone?(value)
          TIMEZONE_SUFFIX.match?(value)
        end

        # Logs a coercion failure at debug level and returns the original value.
        #
        # @param value [String] the value that could not be coerced
        # @param target_type [String] the XSD type name that was attempted
        # @return [String] the original value, unchanged
        def coercion_fallback(value, target_type)
          logger.debug("Type coercion failed: cannot convert #{value.inspect} to #{target_type}")
          value
        end
      end
    end
  end
end
