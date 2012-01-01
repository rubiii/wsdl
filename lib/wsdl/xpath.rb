module WSDL
  class XPath
    include Enumerable

    def initialize(node)
      @node = node
    end

    attr_reader :node

    def each
      node.xpath(joined_xpath, WSDL.namespaces).each { |el| yield el }
    end

    def children(&query)
      node.children.find(&query)
    end

    def wsdl(*elements)
      elements.each { |el| xpath << "wsdl:#{el}" }
      self
    end

  private

    def xpath
      @xpath ||= []
    end

    def joined_xpath
      xpath.join("/")
    end

  end
end
