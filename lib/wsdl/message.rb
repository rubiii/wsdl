module WSDL
  class Message

    attr_accessor :name

    def parts
      @parts ||= []
    end

  end
end
