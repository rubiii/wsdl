# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL service element.
    #
    # A service groups a set of related ports together. Each port defines
    # a single endpoint that combines a binding with a network address.
    # Services are the top-level entry point for discovering available
    # endpoints in a WSDL document.
    #
    # @api private
    #
    class Service
      # Creates a new Service from a WSDL service XML node.
      #
      # @param service_node [Nokogiri::XML::Node] the wsdl:service element
      def initialize(service_node)
        @service_node = service_node
      end

      # Returns the name of this service.
      #
      # @return [String] the service name
      def name
        @service_node['name']
      end

      # Returns the ports defined in this service.
      #
      # @return [Hash<String, Port>] a hash of port names to port objects
      def ports
        @ports ||= ports!
      end

      # Converts this service to a Hash representation.
      #
      # @return [Hash] a hash with the service name as key and ports as values
      # @example
      #   service.to_hash
      #   # => { "ServiceName" => {
      #   #        ports: {
      #   #          "PortName" => { type: "...", location: "..." }
      #   #        }
      #   #      }
      #   #    }
      def to_hash
        port_hash = ports.values.inject({}) { |memo, port| memo.merge port.to_hash }
        { name => { ports: port_hash } }
      end

      private

      # Parses and returns all ports from the service node.
      #
      # Only ports with SOAP address elements (SOAP 1.1 or 1.2) are included.
      # Non-SOAP ports are skipped.
      #
      # @return [Hash<String, Port>] the parsed ports
      def ports!
        ports = {}

        @service_node.element_children.each do |port_node|
          next unless port_node.name == 'port'

          soap_node = port_node.element_children.find { |node|
            namespace = node.namespace.href

            soap11  = namespace == NS::WSDL_SOAP_1_1
            soap12  = namespace == NS::WSDL_SOAP_1_2
            address = node.name == 'address'

            (soap11 || soap12) && address
          }

          next unless soap_node

          port_name = port_node['name']
          port = Port.new(port_node, soap_node)

          ports[port_name] = port
        end

        ports
      end
    end
  end
end
