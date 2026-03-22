# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL binding operation element.
    #
    # A binding operation defines the protocol-specific details for a
    # particular operation, including the SOAP action, style, and the
    # format of input/output messages (headers and body).
    #
    # @api private
    #
    class BindingOperation
      # Creates a new BindingOperation from a WSDL operation XML node.
      #
      # @param operation_node [Nokogiri::XML::Node] the wsdl:operation element within a binding
      # @param defaults [Hash] default values inherited from the parent binding
      # @option defaults [String] :style the default operation style ('document' or 'rpc')
      def initialize(operation_node, defaults = {})
        @operation_node = operation_node

        if (soap_operation_node = find_soap_operation_node)
          namespace = soap_operation_node.first
          node = soap_operation_node.last

          @soap_namespace = namespace
          @soap_action = node['soapAction']
          @style = node['style'] || defaults[:style]
        end

        @input_wrapper = find_wrapper_node('input')
        @output_wrapper = find_wrapper_node('output')
        @input_name = @input_wrapper&.[]('name')
        @output_name = @output_wrapper&.[]('name')
      end

      # @return [String, nil] the SOAPAction HTTP header value
      attr_reader :soap_action

      # @return [String] the operation style ('document' or 'rpc')
      attr_reader :style

      # @return [String] the SOAP namespace URI (1.1 or 1.2)
      attr_reader :soap_namespace

      # @return [String, nil] the name attribute of the input wrapper element
      attr_reader :input_name

      # @return [String, nil] the name attribute of the output wrapper element
      attr_reader :output_name

      # Returns the name of this operation.
      #
      # @return [String] the operation name
      def name
        @operation_node['name']
      end

      # Returns the input header definitions for this operation.
      #
      # Each header is represented as a Hash with keys:
      # - `encoding_style` - the encoding style URI
      # - `namespace` - the namespace URI
      # - `use` - 'literal' or 'encoded'
      # - `message` - the message name (qualified)
      # - `part` - the part name within the message
      #
      # @return [Array<HeaderReference>] the input header references
      def input_headers
        return @input_headers if @input_headers

        header_nodes = find_input_child_nodes('header') || []
        @input_headers = build_headers(header_nodes)
      end

      # Returns the input body definition for this operation.
      #
      # The body is represented as a Hash with keys:
      # - `:encoding_style` - the encoding style URI
      # - `:namespace` - the namespace URI for RPC-style messages
      # - `:use` - 'literal' or 'encoded'
      #
      # @return [Hash] the input body definition
      def input_body
        return @input_body if @input_body

        input_body = {}

        if (body_node = find_input_child_nodes('body').first)
          input_body = {
            encoding_style: body_node['encodingStyle'],
            namespace: body_node['namespace'],
            use: body_node['use']
          }
        end

        @input_body = input_body
      end

      # Returns the output header definitions for this operation.
      #
      # Each header is represented as a Hash with keys:
      # - `encoding_style` - the encoding style URI
      # - `namespace` - the namespace URI
      # - `use` - 'literal' or 'encoded'
      # - `message` - the message name (qualified)
      # - `part` - the part name within the message
      #
      # @return [Array<HeaderReference>] the output header references
      def output_headers
        return @output_headers if @output_headers

        header_nodes = find_output_child_nodes('header') || []
        @output_headers = build_headers(header_nodes)
      end

      # Returns the output body definition for this operation.
      #
      # The body is represented as a Hash with keys:
      # - `:encoding_style` - the encoding style URI
      # - `:namespace` - the namespace URI for RPC-style messages
      # - `:use` - 'literal' or 'encoded'
      #
      # @return [Hash] the output body definition
      def output_body
        return @output_body if @output_body

        output_body = {}

        if (body_node = find_output_child_nodes('body')&.first)
          output_body = {
            encoding_style: body_node['encodingStyle'],
            namespace: body_node['namespace'],
            use: body_node['use']
          }
        end

        @output_body = output_body
      end

      private

      # Finds child nodes of a specific type within the input element.
      #
      # @param child_name [String] the name of the child element to find
      # @return [Array<Nokogiri::XML::Node>] the matching child nodes
      # @raise [Error] if the binding operation has no input element
      def find_input_child_nodes(child_name)
        unless @input_wrapper
          op_name = @operation_node['name']
          raise UnresolvedReferenceError.new(
            "Binding operation #{op_name.inspect} is missing a required <input> element",
            reference_type: :input,
            reference_name: 'input',
            context: "binding operation #{op_name.inspect}"
          )
        end

        @input_wrapper.element_children.select { |node| node.name == child_name }
      end

      # Finds child nodes of a specific type within the output element.
      #
      # @param child_name [String] the name of the child element to find
      # @return [Array<Nokogiri::XML::Node>, nil] the matching child nodes
      def find_output_child_nodes(child_name)
        return unless @output_wrapper

        @output_wrapper.element_children.select { |node| node.name == child_name }
      end

      # Finds a wrapper node (input or output) within the operation element.
      #
      # @param direction [String] 'input' or 'output'
      # @return [Nokogiri::XML::Node, nil] the wrapper node
      def find_wrapper_node(direction)
        @operation_node.element_children.find { |n| n.name == direction }
      end

      # Builds normalized header metadata from SOAP header nodes.
      #
      # @param header_nodes [Array<Nokogiri::XML::Node>] SOAP header nodes
      # @return [Array<HeaderReference>] normalized header metadata
      def build_headers(header_nodes)
        header_nodes.map { |header_node| HeaderReference.from_node(header_node) }
      end

      # Finds the SOAP operation element within this binding operation.
      #
      # @return [Array<String, Nokogiri::XML::Node>, nil] a tuple of [namespace, node], or nil if not found
      def find_soap_operation_node
        @operation_node.element_children.each do |node|
          namespace = node.namespace.href

          soap11    = namespace == NS::WSDL_SOAP_1_1
          soap12    = namespace == NS::WSDL_SOAP_1_2
          operation = node.name == 'operation'

          return [namespace, node] if (soap11 || soap12) && operation
        end

        nil
      end
    end
  end
end
