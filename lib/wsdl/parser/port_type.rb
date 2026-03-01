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
      # @return [Hash<String, PortTypeOperation>] a hash of operation names to port type operations
      def operations
        @operations ||= operations!
      end

      private

      # Parses and returns all operations from the port type node.
      #
      # @return [Hash<String, PortTypeOperation>] the parsed operations
      def operations!
        operations = {}

        @port_type_node.element_children.each do |operation_node|
          next unless operation_node.name == 'operation'

          operation_name = operation_node['name']
          operation = PortTypeOperation.new(operation_node)

          operations[operation_name] = operation
        end

        operations
      end
    end
  end
end
