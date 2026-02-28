# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:complexType definition.
    #
    # Complex types define elements that can contain child elements
    # and/or attributes. They define the content model through
    # compositors (sequence, choice, all) and may extend or restrict
    # other types.
    #
    class ComplexType < PrimaryType
      # Returns all child element definitions within this complex type.
      #
      # Delegates to {BaseType#collect_child_elements} to recursively
      # gather elements from nested compositors.
      #
      # @return [Array<Element>] the child element definitions
      alias elements collect_child_elements

      # Returns all attribute definitions for this complex type.
      #
      # Delegates to {BaseType#collect_attributes} to recursively
      # gather attributes from nested groups.
      #
      # @return [Array<Attribute>] the attribute definitions
      alias attributes collect_attributes

      # Returns a unique identifier for this complex type.
      #
      # The ID is used to detect recursive type definitions during
      # element building.
      #
      # @return [String] the type ID in "namespace:name" format
      def id
        [namespace, name].join(':')
      end
    end
  end
end
