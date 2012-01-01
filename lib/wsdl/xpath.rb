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

    def query(selector, value)
      node.children.find { |node| node.send(selector) == value }
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
