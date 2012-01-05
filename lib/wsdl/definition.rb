module WSDL
  class Definition

    attr_accessor :name, :target_namespace, :namespaces

    def messages
      @messages ||= []
    end

  end
end
