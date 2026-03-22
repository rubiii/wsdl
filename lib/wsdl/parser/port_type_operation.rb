# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL portType operation element.
    #
    # A port type operation defines an abstract operation as part of a
    # port type interface. It specifies the input and output messages
    # that define the operation's interface contract, independent of
    # any protocol binding.
    #
    # @api private
    #
    class PortTypeOperation
      # Creates a new PortTypeOperation from a WSDL operation XML node.
      #
      # @param operation_node [Nokogiri::XML::Node] the wsdl:operation element within a portType
      def initialize(operation_node)
        @operation_node = operation_node

        @name = operation_node['name']
        @input_node = find_node('input')
        @output_node = find_node('output')
      end

      # @return [String] the name of this operation
      attr_reader :name

      # Returns the input message definition for this operation.
      #
      # @return [MessageReference] parsed message reference
      # @example
      #   operation.input
      #   # => #<data WSDL::Parser::MessageReference ...>
      def input
        return @input if defined? @input

        @input = parse_node(@input_node)
      end

      # Returns the output message definition for this operation.
      #
      # @return [MessageReference] parsed message reference
      # @example
      #   operation.output
      #   # => #<data WSDL::Parser::MessageReference ...>
      def output
        return @output if defined? @output

        @output = @output_node ? parse_node(@output_node) : nil
      end

      private

      # Finds a child node by name within the operation element.
      #
      # @param node_name [String] the name of the child element to find
      # @return [Nokogiri::XML::Node, nil] the matching node, or nil if not found
      def find_node(node_name)
        @operation_node.element_children.find { |node| node.name == node_name }
      end

      # Parses an input or output node into a message reference.
      #
      # @param node [Nokogiri::XML::Node] the input or output node
      # @return [MessageReference] parsed message reference
      def parse_node(node)
        MessageReference.from_node(node)
      end
    end
  end
end
