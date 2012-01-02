%w(qname xpath namespace).each do |lib|
  require File.expand_path("../#{lib}", __FILE__)
end

module WSDL
  class Parser

    def initialize(document)
      @document = document
    end

    attr_reader :document

    def parse
      @bindings = parse_bindings
      @services = parse_services

      { "services" => @services }
    end

  private

    def parse_bindings
      xpath.wsdl(:definitions, :binding).inject({}) do |bindings, binding|
        details = {}

        transport_binding = xpath(binding).query(:name, "binding")
        if namespace(transport_binding).soap?
          details["style"] = transport_binding["style"]
          details["transport"] = transport_binding["transport"]
        end

        details["operations"] = find_operations(binding)

        bindings[binding["name"]] = details
        bindings
      end
    end

    def parse_services
      xpath.wsdl(:definitions, :service).inject({}) do |services, service|
        services[service["name"]] = { "ports" => find_ports(service) }
        services
      end
    end

    def find_operations(binding)
      xpath(binding).wsdl(:operation).inject({}) do |operations, operation|
        details = {}

        transport_operation = xpath(operation).query(:name, "operation")
        if transport_operation && namespace(transport_operation).soap?
          # NOTE: Nokogiri Java returns nil instead of an empty String for empty attributes.
          #       https://github.com/tenderlove/nokogiri/issues/589
          details["soap_action"] = transport_operation["soapAction"] || ""
          details["style"] = transport_operation["style"]

          details["input"]  = find_operation_body(xpath(operation).wsdl(:input)).first
          details["output"] = find_operation_body(xpath(operation).wsdl(:output)).first
          details["fault"]  = find_operation_body(xpath(operation).wsdl(:fault))
        end

        operations[operation["name"]] = details
        operations
      end
    end

    def find_operation_body(nodes)
      nodes.map do |node|
        body = xpath(node).query(:name, "body")
        { "use" => body["use"] }
      end
    end

    def find_ports(service)
      xpath(service).wsdl(:port).inject({}) do |ports, port|
        address_node = port.children.find(&:element?)
        binding_name = qname(port["binding"]).local

        ports[port["name"]] = {
          "type"     => namespace(address_node).type,
          "location" => address_node["location"],
          "binding"  => @bindings[binding_name]
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
