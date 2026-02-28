# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:simpleType definition.
    #
    # Simple types define restrictions on built-in types or other simple
    # types. They contain only text content, not child elements.
    #
    class SimpleType < PrimaryType
      # Returns the base type for this simple type restriction.
      #
      # Looks for an xs:restriction child element and returns its
      # base attribute value.
      #
      # @return [String, nil] the base type name (e.g., 'xsd:string')
      def base
        child = @node.element_children.first
        local = child.name.split(':').last

        child['base'] if local == 'restriction'
      end
    end
  end
end
