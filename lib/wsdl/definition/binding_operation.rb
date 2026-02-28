# frozen_string_literal: true

class WSDL
  class Definition
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
      end

      # @return [String, nil] the SOAPAction HTTP header value
      attr_reader :soap_action

      # @return [String] the operation style ('document' or 'rpc')
      attr_reader :style

      # @return [String] the SOAP namespace URI (1.1 or 1.2)
      attr_reader :soap_namespace

      # Returns the name of this operation.
      #
      # @return [String] the operation name
      def name
        @operation_node['name']
      end

      # Returns the input header definitions for this operation.
      #
      # Each header is represented as a Hash with keys:
      # - `:encoding_style` - the encoding style URI
      # - `:namespace` - the namespace URI
      # - `:use` - 'literal' or 'encoded'
      # - `:message` - the message name (qualified)
      # - `:part` - the part name within the message
      #
      # @return [Array<Hash>] the input header definitions
      def input_headers
        return @input_headers if @input_headers

        input_headers = []

        if (header_nodes = find_input_child_nodes('header'))
          header_nodes.each do |header_node|
            input_headers << {
              encoding_style: header_node['encodingStyle'],
              namespace: header_node['namespace'],
              use: header_node['use'],
              message: header_node['message'],
              part: header_node['part']
            }
          end
        end

        @input_headers = input_headers
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
      # - `:encoding_style` - the encoding style URI
      # - `:namespace` - the namespace URI
      # - `:use` - 'literal' or 'encoded'
      # - `:message` - the message name (qualified)
      # - `:part` - the part name within the message
      #
      # @return [Array<Hash>] the output header definitions
      def output_headers
        return @output_headers if @output_headers

        output_headers = []

        if (header_nodes = find_output_child_nodes('header'))
          header_nodes.each do |header_node|
            output_headers << {
              encoding_style: header_node['encodingStyle'],
              namespace: header_node['namespace'],
              use: header_node['use'],
              message: header_node['message'],
              part: header_node['part']
            }
          end
        end

        @output_headers = output_headers
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

        if (body_node = find_output_child_nodes('body').first)
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
      # @return [Array<Nokogiri::XML::Node>, nil] the matching child nodes
      def find_input_child_nodes(child_name)
        input_node = @operation_node.element_children.find { |node| node.name == 'input' }
        return unless input_node

        input_node.element_children.select { |node| node.name == child_name }
      end

      # Finds child nodes of a specific type within the output element.
      #
      # @param child_name [String] the name of the child element to find
      # @return [Array<Nokogiri::XML::Node>, nil] the matching child nodes
      def find_output_child_nodes(child_name)
        output_node = @operation_node.element_children.find { |node| node.name == 'output' }
        return unless output_node

        output_node.element_children.select { |node| node.name == child_name }
      end

      # Finds the SOAP operation element within this binding operation.
      #
      # @return [Array<String, Nokogiri::XML::Node>, nil] a tuple of [namespace, node], or nil if not found
      def find_soap_operation_node
        @operation_node.element_children.each do |node|
          namespace = node.namespace.href

          soap11    = namespace == WSDL::NS_SOAP_1_1
          soap12    = namespace == WSDL::NS_SOAP_1_2
          operation = node.name == 'operation'

          return [namespace, node] if (soap11 || soap12) && operation
        end

        nil
      end
    end
  end
end
