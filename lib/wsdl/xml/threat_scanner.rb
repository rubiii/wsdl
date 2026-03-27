# frozen_string_literal: true

module WSDL
  module XML
    # Scans raw XML strings for attack patterns without parsing.
    #
    # Provides defense-in-depth threat detection by identifying suspicious
    # patterns before they reach the parser. All scanning operates on
    # binary-encoded strings using byte-level comparisons to avoid
    # allocations from regex match objects.
    #
    # Detected threats:
    # - +:doctype+ — DOCTYPE declaration (XXE vector)
    # - +:entity_declaration+ — ENTITY definitions
    # - +:external_reference+ — SYSTEM or PUBLIC identifiers
    # - +:parameter_entity+ — Parameter entity references (+%entity;+)
    # - +:deep_nesting+ — Excessive open tags (>{MAX_OPEN_TAGS})
    # - +:large_attribute+ — Single attribute value >{MAX_ATTRIBUTE_VALUE_SIZE} bytes
    # - +:large_attributes_total+ — Cumulative attribute size >{MAX_TOTAL_ATTRIBUTE_SIZE} bytes
    #
    # @example
    #   scanner = ThreatScanner.new(xml_string)
    #   threats = scanner.scan
    #   # => [:doctype, :entity_declaration]
    #
    # @api private
    class ThreatScanner
      # Maximum number of open tags before flagging deep nesting.
      # @return [Integer]
      MAX_OPEN_TAGS = 1_000

      # Maximum size of a single attribute value in bytes.
      # @return [Integer]
      MAX_ATTRIBUTE_VALUE_SIZE = 10_000

      # Maximum cumulative size of all attribute values in bytes.
      # @return [Integer]
      MAX_TOTAL_ATTRIBUTE_SIZE = 1_000_000

      # @!group Byte Constants

      # @return [Integer]
      SLASH_BYTE = '/'.ord
      # @return [Integer]
      BANG_BYTE = '!'.ord
      # @return [Integer]
      QUESTION_BYTE = '?'.ord
      # @return [Integer]
      DOUBLE_QUOTE_BYTE = '"'.ord
      # @return [Integer]
      SINGLE_QUOTE_BYTE = "'".ord

      # Whitespace byte values: space, tab, LF, CR.
      # @return [Set<Integer>]
      WHITESPACE_BYTES = Set[0x20, 0x09, 0x0A, 0x0D].freeze

      # Quote byte values: double quote and single quote.
      # @return [Set<Integer>]
      QUOTE_BYTES = Set[DOUBLE_QUOTE_BYTE, SINGLE_QUOTE_BYTE].freeze

      # Non-open-tag byte values: closing (+/+), declaration (+!+), processing instruction (+?+).
      # @return [Set<Integer>]
      NON_OPEN_TAG_BYTES = Set[SLASH_BYTE, BANG_BYTE, QUESTION_BYTE].freeze

      # Pre-computed binary quote character strings, keyed by byte value.
      # Avoids allocating a new String via +Integer#chr+ on every call.
      # @return [Hash{Integer => String}]
      QUOTE_CHARS = {
        DOUBLE_QUOTE_BYTE => '"'.b.freeze,
        SINGLE_QUOTE_BYTE => "'".b.freeze
      }.freeze

      # @!endgroup

      # @param xml_string [String] the XML string to scan
      def initialize(xml_string)
        @bin = xml_string.b
      end

      # Scans for all threat patterns and returns unique threat symbols.
      #
      # @return [Array<Symbol>] detected threat indicators
      def scan
        threats = []

        threats << :doctype            if @bin.match?(/<!DOCTYPE/i)
        threats << :entity_declaration if @bin.match?(/<!ENTITY/i)
        threats << :external_reference if @bin.match?(/\bSYSTEM\s+["']/i)
        threats << :external_reference if @bin.match?(/\bPUBLIC\s+["']/i)
        threats << :parameter_entity   if @bin.match?(/%[a-zA-Z_][a-zA-Z0-9_]*;/)
        threats << :deep_nesting       if count_open_tags > MAX_OPEN_TAGS
        threats.concat(scan_attribute_threats)

        threats.uniq
      end

      # Counts open XML tags using byte-level scanning.
      #
      # Matches tags that start with an ASCII letter and are not closing
      # tags (+</+), comments (+<!+), or processing instructions (+<?+).
      #
      # @return [Integer] the number of open tags found
      def count_open_tags
        count = 0
        pos = 0

        while (pos = @bin.index('<', pos))
          byte = @bin.getbyte(pos + 1)
          count += 1 if open_tag_start?(byte)
          pos += 1
        end

        count
      end

      # Scans attribute values for size-based threats.
      #
      # Locates +=+ followed by a quoted string, then measures each
      # value's length via position arithmetic (zero allocations).
      #
      # @return [Array<Symbol>] detected attribute threats
      def scan_attribute_threats
        threats = []
        total_size = 0
        pos = 0

        while pos < @bin.size
          eq_pos = @bin.index('=', pos)
          break unless eq_pos

          measure_attribute_value(eq_pos)
          pos = @measured_next_pos
          next unless @measured_value_length

          total_size += @measured_value_length
          threats << :large_attribute if @measured_value_length > MAX_ATTRIBUTE_VALUE_SIZE
        end

        threats << :large_attributes_total if total_size > MAX_TOTAL_ATTRIBUTE_SIZE
        threats
      end

      private

      # Measures a single attribute value starting from the +=+ position.
      # Sets +@measured_value_length+ and +@measured_next_pos+ to avoid
      # allocating a return array on every call.
      #
      # @param eq_pos [Integer] position of the +=+ sign
      # @return [void]
      def measure_attribute_value(eq_pos)
        find_opening_quote(eq_pos + 1)
        unless @opening_quote_byte
          @measured_value_length = nil
          @measured_next_pos = eq_pos + 1
          return
        end

        close_pos = find_closing_quote(@opening_quote_pos, @opening_quote_byte)
        unless close_pos
          @measured_value_length = nil
          @measured_next_pos = eq_pos + 1
          return
        end

        @measured_value_length = close_pos - @opening_quote_pos - 1
        @measured_next_pos = close_pos + 1
      end

      # Checks if the byte following +<+ starts an open tag.
      #
      # @param byte [Integer, nil] the byte after +<+
      # @return [Boolean]
      def open_tag_start?(byte)
        return false unless byte
        return false if NON_OPEN_TAG_BYTES.include?(byte)

        ascii_letter?(byte)
      end

      # Checks if a byte is an ASCII letter (A-Z or a-z).
      #
      # @param byte [Integer] the byte value
      # @return [Boolean]
      def ascii_letter?(byte)
        byte.between?(65, 90) || byte.between?(97, 122)
      end

      # Skips whitespace after a position and sets +@opening_quote_pos+ and
      # +@opening_quote_byte+. Sets +@opening_quote_byte+ to +nil+ when no
      # quote character is found at the resulting position.
      #
      # @param pos [Integer] starting position (after +=+)
      # @return [void]
      def find_opening_quote(pos)
        byte = @bin.getbyte(pos)

        while WHITESPACE_BYTES.include?(byte)
          pos += 1
          byte = @bin.getbyte(pos)
        end

        @opening_quote_pos = pos
        @opening_quote_byte = QUOTE_BYTES.include?(byte) ? byte : nil
      end

      # Finds the closing quote matching the opening quote byte.
      #
      # @param quote_pos [Integer] position of the opening quote
      # @param quote_byte [Integer] the opening quote byte value
      # @return [Integer, nil] position of the closing quote
      def find_closing_quote(quote_pos, quote_byte)
        @bin.index(QUOTE_CHARS[quote_byte], quote_pos + 1)
      end
    end
  end
end
