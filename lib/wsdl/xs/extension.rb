# frozen_string_literal: true

class WSDL
  class XS
    # Represents an xs:extension within complexContent or simpleContent.
    #
    # Extensions add additional elements or attributes to a base type.
    # The base type's content is inherited and extended with new definitions.
    #
    class Extension < BaseType
      # Collects child elements including those inherited from the base type.
      #
      # First resolves the base type and includes its elements, then
      # adds any elements defined directly in this extension.
      #
      # @param memo [Array] accumulator for recursive traversal (internal use)
      # @return [Array<Element>] all element definitions including inherited ones
      def collect_child_elements(memo = [])
        if @node['base']
          local, nsid = @node['base'].split(':').reverse
          # When there's no prefix (nsid is nil), use the schema's target namespace
          namespace = nsid ? @node.namespaces["xmlns:#{nsid}"] : @schema[:target_namespace]

          if (complex_type = @schemas.complex_type(namespace, local))
            memo += complex_type.elements

          # TODO: can we find a testcase for this?
          else # if simple_type = @schemas.simple_type(namespace, local)
            raise 'simple type extension?!'
            # memo << simple_type
          end
        end

        super
      end
    end
  end
end
