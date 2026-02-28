# frozen_string_literal: true

class WSDL
  class XS
    # Represents xs:simpleContent for complex types with text-only content.
    #
    # Simple content types can have attributes but their content is
    # restricted to simple (text) values.
    #
    class SimpleContent < BaseType
      # Stop searching for attributes in simple content.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_attributes(memo = [])
        memo
      end

      # Stop searching for child elements in simple content.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end
  end
end
