# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:any wildcard element.
    #
    # The any element allows arbitrary well-formed XML content to appear
    # at a specific point in a complex type definition. It acts as a
    # wildcard placeholder that can match any element.
    #
    # @see https://www.w3.org/TR/xmlschema-1/#element-any
    #
    class Any < BaseType
      # Returns the namespace constraint for this wildcard.
      #
      # @return [String] the namespace attribute value (e.g., '##any', '##other', or a URI)
      def namespace_constraint
        @node['namespace'] || '##any'
      end

      # Returns how content should be validated.
      #
      # @return [String] 'strict', 'lax', or 'skip'
      def process_contents
        @node['processContents'] || 'strict'
      end

      # Returns whether this wildcard allows multiple elements.
      #
      # @return [Boolean] true if maxOccurs is unbounded or > 1
      def multiple?
        max = @node['maxOccurs'].to_s
        max == 'unbounded' || max.to_i > 1
      end

      # Returns whether this wildcard is optional.
      #
      # @return [Boolean] true if minOccurs is 0
      def optional?
        @node['minOccurs'].to_s == '0'
      end

      # Wildcards don't contribute named child elements to the schema model.
      # Instead, they signal that arbitrary content is allowed.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array] the unchanged memo array
      def collect_child_elements(memo = [])
        # xs:any wildcards don't have predefined child elements
        # The parent type will handle this specially
        memo
      end
    end
  end
end
