%w(version parser).each do |lib|
  require File.expand_path("../wsdl/#{lib}", __FILE__)
end

module WSDL

  NAMESPACES = {
    "xs"     => "http://www.w3.org/2001/XMLSchema",
    "wsdl"   => "http://schemas.xmlsoap.org/wsdl/",
    "http"   => "http://schemas.xmlsoap.org/wsdl/http/",
    "soap11" => "http://schemas.xmlsoap.org/wsdl/soap/",
    "soap12" => "http://schemas.xmlsoap.org/wsdl/soap12/"
  }

  def self.namespaces
    @namespaces ||= NAMESPACES.dup
  end

  def self.namespaces_by_value
    @namespaces_by_value ||= namespaces.invert
  end

end
