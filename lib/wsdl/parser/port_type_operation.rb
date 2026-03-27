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
      # @param namespaces [Hash{String => String}, nil] pre-resolved namespace
      #   declarations shared across sibling operations under the same portType
      def initialize(operation_node, namespaces: nil)
        @operation_node = operation_node
        @namespaces = namespaces

        @name = operation_node['name']
        @input_node = find_node('input')
        @output_node = find_node('output')
      end

      # @return [String] the name of this operation
      attr_reader :name

      # Returns the name attribute of the input element.
      #
      # Used by {OperationMap} for overload disambiguation.
      #
      # @return [String, nil] the input name, or nil if not specified
      def input_name
        input&.name
      end

      # Returns the input message definition for this operation.
      #
      # @return [MessageReference] parsed message reference
      # @example
      #   operation.input
      #   # => #<data WSDL::Parser::MessageReference ...>
      def input
        return @input if defined? @input

        @input = @input_node ? parse_node(@input_node) : nil
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

      # Returns the namespace declarations for this operation's scope.
      #
      # When a pre-resolved hash was passed via the constructor (shared
      # across sibling operations by {PortType#operations}), it is
      # returned directly. Otherwise, falls back to resolving from the
      # operation node and freezing the result.
      #
      # @return [Hash{String => String}] frozen namespace declarations
      def namespaces
        @namespaces ||= @operation_node.namespaces.freeze
      end

      # Parses an input or output node into a message reference.
      #
      # @param node [Nokogiri::XML::Node] the input or output node
      # @return [MessageReference] parsed message reference
      def parse_node(node)
        MessageReference.from_node(node, namespaces:)
      end
    end
  end
end
