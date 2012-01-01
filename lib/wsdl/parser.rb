require "wsdl/qname"
require "wsdl/xpath"
require "wsdl/namespace"

module WSDL
  class Parser

    def initialize(document)
      @document = document
    end

    attr_reader :document

    def parse
      @services = parse_services
      { "services" => @services }
    end

  private

    def parse_services
      xpath.wsdl(:definitions, :service).inject({}) do |services, service|
        services[service["name"]] = { "ports" => find_ports(service) }
        services
      end
    end

    def find_ports(service)
      xpath(service).wsdl(:port).inject({}) do |ports, port|
        address_node = port.children.find(&:element?)

        ports[port["name"]] = {
          "type"     => namespace(address_node).type,
          "location" => address_node["location"]
        }
        ports
      end
    end

    def qname(node)
      QName.new(node)
    end

    def namespace(qname)
      Namespace.new(qname)
    end

    def xpath(node = nil)
      XPath.new node || document
    end

  end
end
