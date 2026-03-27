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
      # Shared empty frozen array used as default for header node lists.
      # @return [Array] empty frozen array
      # @api private
      EMPTY_NODES = [].freeze

      # Creates a new BindingOperation from a WSDL operation XML node.
      #
      # Categorizes all child elements in a single pass to avoid repeated
      # Nokogiri element_children traversals and node_name allocations.
      #
      # @param operation_node [Nokogiri::XML::Node] the wsdl:operation element within a binding
      # @param defaults [Hash] default values inherited from the parent binding
      # @option defaults [String] :style the default operation style ('document' or 'rpc')
      def initialize(operation_node, defaults = {})
        @operation_node = operation_node
        @has_input = false
        @input_body_node = nil
        @input_header_nodes = EMPTY_NODES
        @output_body_node = nil
        @output_header_nodes = EMPTY_NODES

        categorize_children!(defaults)
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

      # Returns whether this binding operation has an input element.
      #
      # @return [Boolean] true if the binding operation defines an input
      def input?
        @has_input
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
        @input_headers ||= @input_header_nodes.map { |node| HeaderReference.from_node(node) }
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
        @input_body ||= build_body(@input_body_node)
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
        @output_headers ||= @output_header_nodes.map { |node| HeaderReference.from_node(node) }
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
        @output_body ||= build_body(@output_body_node)
      end

      private

      # Single-pass categorization of all operation children.
      #
      # Traverses element_children once to find the SOAP operation, input, and
      # output nodes. Also pre-categorizes each wrapper's children (body/header
      # nodes) to avoid repeated element_children calls when accessors are invoked.
      #
      # @param defaults [Hash] default values inherited from the parent binding
      # @return [void]
      def categorize_children!(defaults)
        @operation_node.element_children.each do |child|
          case child.name
          when 'operation'
            extract_soap_operation!(child, defaults)
          when 'input'
            @has_input = true
            @input_name = child['name']
            categorize_input_children!(child)
          when 'output'
            @output_name = child['name']
            categorize_output_children!(child)
          end
        end
      end

      # Extracts SOAP operation metadata from a soap:operation or soap12:operation node.
      #
      # @param node [Nokogiri::XML::Node] a child element of the binding operation
      # @param defaults [Hash] default values inherited from the parent binding
      # @return [void]
      def extract_soap_operation!(node, defaults)
        namespace = node.namespace&.href

        soap11 = namespace == NS::WSDL_SOAP_1_1
        soap12 = namespace == NS::WSDL_SOAP_1_2
        return unless soap11 || soap12

        @soap_namespace = namespace
        @soap_action = node['soapAction']
        @style = node['style'] || defaults[:style]
      end

      # Pre-categorizes the input wrapper's children into body and header nodes.
      #
      # @param wrapper [Nokogiri::XML::Node] the input wrapper node
      # @return [void]
      def categorize_input_children!(wrapper)
        headers = nil

        wrapper.element_children.each do |child|
          case child.name
          when 'body'   then @input_body_node = child
          when 'header' then (headers ||= []) << child
          end
        end

        @input_header_nodes = headers if headers
      end

      # Pre-categorizes the output wrapper's children into body and header nodes.
      #
      # @param wrapper [Nokogiri::XML::Node] the output wrapper node
      # @return [void]
      def categorize_output_children!(wrapper)
        headers = nil

        wrapper.element_children.each do |child|
          case child.name
          when 'body'   then @output_body_node = child
          when 'header' then (headers ||= []) << child
          end
        end

        @output_header_nodes = headers if headers
      end

      # Builds a body definition hash from a SOAP body node.
      #
      # @param body_node [Nokogiri::XML::Node, nil] the soap:body node
      # @return [Hash] the body definition
      def build_body(body_node)
        return {} unless body_node

        {
          encoding_style: body_node['encodingStyle'],
          namespace: body_node['namespace'],
          use: body_node['use']
        }
      end
    end
  end
end
