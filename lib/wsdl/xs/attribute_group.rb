# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:attributeGroup definition or reference.
    #
    # Attribute groups allow reusing sets of attribute declarations
    # across multiple complex types.
    #
    class AttributeGroup < BaseType
      # Returns all attributes in this group including referenced groups.
      #
      # Delegates to {BaseType#collect_attributes}.
      #
      # @return [Array<Attribute>] the attribute definitions
      alias attributes collect_attributes

      # Collects attributes including those from referenced attribute groups.
      #
      # If this is a reference (@ref), resolves the referenced group
      # and includes its attributes.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Attribute>] all attribute definitions
      def collect_attributes(memo = [])
        if @node['ref']
          local, nsid = @node['ref'].split(':').reverse
          # When there's no prefix (nsid is nil), use the schema's target namespace
          namespace = nsid ? @node.namespaces["xmlns:#{nsid}"] : @schema[:target_namespace]

          attribute_group = @schemas.attribute_group(namespace, local)
          memo + attribute_group.attributes
        else
          super
        end
      end
    end
  end
end
