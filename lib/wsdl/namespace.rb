module WSDL
  class Namespace

    def initialize(node)
      self.node = node
    end

    attr_accessor :node

    def soap?
      type == "soap11" || type == "soap12"
    end

    def href
      node.namespace.href
    end

    def type
      WSDL.namespaces_by_value[href]
    end

  end
end
