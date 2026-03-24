# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL port element within a service.
    #
    # A port defines a single endpoint for a service by associating a binding
    # with a network address. It specifies where and how to communicate with
    # the service using a particular protocol binding.
    #
    # @api private
    #
    class Port
      # Creates a new Port from WSDL port and SOAP address XML nodes.
      #
      # @param port_node [Nokogiri::XML::Node] the wsdl:port element
      # @param soap_node [Nokogiri::XML::Node] the soap:address or soap12:address element
      def initialize(port_node, soap_node)
        @port_node = port_node
        @name     = port_node['name']
        @binding  = port_node['binding']

        @type     = soap_node.namespace.href
        @location = soap_node['location']
      end

      # @return [String] the name of this port
      attr_reader :name

      # @return [String] the qualified name of the binding this port uses
      attr_reader :binding

      # @return [String] the SOAP namespace URI indicating the protocol version
      attr_reader :type

      # @return [String] the endpoint URL for this port
      attr_reader :location

      # Fetches the binding that this port references.
      #
      # @param documents [DocumentCollection] the document collection to search
      # @return [Binding] the binding object
      # @raise [UnresolvedReferenceError] if the binding cannot be found
      def fetch_binding(documents)
        binding_name = QName.parse(
          @binding,
          namespaces: @port_node.namespaces,
          default_namespace: QName.document_namespace(@port_node.document.root)
        )

        documents.bindings.fetch(binding_name) do
          raise UnresolvedReferenceError.new(
            "Unable to find binding #{binding_name} for port #{@name.inspect}",
            reference_type: :binding,
            reference_name: binding_name.to_s,
            context: "port #{@name.inspect}"
          )
        end
      end

      # Converts this port to a Hash representation.
      #
      # @return [Hash] a hash with the port name as key and type/location as values
      # @example
      #   port.to_hash
      #   # => { "PortName" => { type: "http://schemas.xmlsoap.org/wsdl/soap/",
      #   #                      location: "http://example.com/service" } }
      def to_hash
        { name => { type:, location: } }
      end
    end
  end
end
