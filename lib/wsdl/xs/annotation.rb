# frozen_string_literal: true

class WSDL
  class XS
    # Represents xs:annotation for documentation and app info.
    #
    # Annotations provide human-readable documentation and
    # application-specific information but don't affect the
    # type structure.
    #
    class Annotation < BaseType
      # Stop searching for attributes in annotations.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_attributes(memo = [])
        memo
      end

      # Stop searching for child elements in annotations.
      #
      # @param memo [Array] ignored
      # @return [Array] an empty array
      def collect_child_elements(memo = [])
        memo
      end
    end
  end
end
