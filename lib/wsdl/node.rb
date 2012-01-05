module WSDL
  class Node

    def initialize(namespace_uri, name)
      @namespace_uri = namespace_uri
      @name = name
    end

    attr_accessor :namespace_uri, :name

    def type
      name
    end

  end
end
