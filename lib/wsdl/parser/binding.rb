# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL binding element.
    #
    # A binding defines the message format and protocol details for operations
    # defined by a particular port type. It specifies the concrete protocol
    # (SOAP 1.1 or 1.2) and data format (document or RPC style) to be used.
    #
    # @api private
    #
    class Binding
      # Creates a new Binding from a WSDL binding XML node.
      #
      # @param binding_node [Nokogiri::XML::Node] the wsdl:binding element
      def initialize(binding_node)
        @binding_node = binding_node

        @name = binding_node['name']
        @port_type = binding_node['type']

        if (soap_node = find_soap_node)
          @style = soap_node['style'] || 'document'
          @transport = soap_node['transport']
        end
      end

      # @return [String] the name of this binding
      attr_reader :name

      # @return [String] the qualified name of the port type this binding implements
      attr_reader :port_type

      # @return [String] the default style for operations ('document' or 'rpc')
      attr_reader :style

      # @return [String] the transport URI (e.g., HTTP)
      attr_reader :transport

      # Fetches the port type that this binding implements.
      #
      # @param documents [DocumentCollection] the document collection to search
      # @return [PortType] the port type object
      # @raise [UnresolvedReferenceError] if the port type cannot be found
      def fetch_port_type(documents)
        port_type_name = QName.parse(
          @port_type,
          namespaces: @binding_node.namespaces,
          default_namespace: QName.document_namespace(@binding_node.document.root)
        )

        documents.port_types.fetch(port_type_name) do
          raise UnresolvedReferenceError.new(
            "Unable to find portType #{port_type_name} for binding #{@name.inspect}",
            reference_type: :port_type,
            reference_name: port_type_name.to_s,
            context: "binding #{@name.inspect}"
          )
        end
      end

      # Returns the operations defined in this binding.
      #
      # @return [Hash{String => BindingOperation}] a hash of operation names to binding operations
      def operations
        @operations ||= operations!
      end

      private

      # Parses and returns all operations from the binding node.
      #
      # @return [Hash{String => BindingOperation}] the parsed operations
      def operations!
        operations = {}

        @binding_node.element_children.each do |operation_node|
          next unless operation_node.name == 'operation'

          operation_name = operation_node['name']
          operation = BindingOperation.new(operation_node, style: @style)

          operations[operation_name] = operation
        end

        operations
      end

      # Finds the SOAP binding element within this binding.
      #
      # Looks for a soap:binding or soap12:binding child element that
      # specifies the SOAP protocol details.
      #
      # @return [Nokogiri::XML::Node, nil] the SOAP binding node, or nil if not found
      def find_soap_node
        @binding_node.element_children.find do |node|
          namespace = node.namespace.href

          soap11  = namespace == NS::WSDL_SOAP_1_1
          soap12  = namespace == NS::WSDL_SOAP_1_2
          binding = node.name == 'binding'

          (soap11 || soap12) && binding
        end
      end
    end
  end
end
