# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL portType element.
    #
    # A port type defines an abstract set of operations supported by one
    # or more endpoints. Each operation specifies input and output messages
    # that define the interface contract, independent of protocol bindings.
    #
    # @api private
    #
    class PortType
      # Creates a new PortType from a WSDL portType XML node.
      #
      # @param port_type_node [Nokogiri::XML::Node] the wsdl:portType element
      def initialize(port_type_node)
        @port_type_node = port_type_node
      end

      # Returns the name of this port type.
      #
      # @return [String] the port type name
      def name
        @port_type_node['name']
      end

      # Returns the operations defined in this port type.
      #
      # @return [OperationMap] the operations indexed by name
      def operations
        @operations ||= operations!
      end

      private

      # Parses and returns all operations from the port type node.
      #
      # All wsdl:operation children share the same namespace scope from
      # the parent wsdl:portType element, so we resolve it once and
      # share the frozen hash across every operation.
      #
      # @return [OperationMap] the parsed operations
      def operations!
        map = OperationMap.new
        namespaces = @port_type_node.namespaces.freeze

        @port_type_node.element_children.each do |operation_node|
          next unless operation_node.name == 'operation'

          map.add(operation_node['name'], PortTypeOperation.new(operation_node, namespaces:))
        end

        map
      end
    end
  end
end
