module WSDL
  class QName

    def initialize(qname)
      self.qname = qname
      self.local, self.prefix = qname.split(":").reverse
    end

    attr_accessor :qname, :prefix, :local

  end
end
