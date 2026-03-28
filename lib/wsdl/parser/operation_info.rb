# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL operation with its binding and port type information.
    #
    # This class combines information from the binding operation (protocol details)
    # and port type operation (abstract interface) to provide a complete view of
    # an operation that can be invoked.
    #
    # @api private
    #
    class OperationInfo
      # Creates a new OperationInfo instance.
      #
      # @param name [String] the operation name
      # @param binding_operation [BindingOperation] the binding operation with protocol details
      # @param port_type_operation [PortTypeOperation] the port type operation with interface details
      # @param documents [DocumentCollection] for resolving message references
      # @param schemas [Schema::Collection] for building element trees
      # @param limits [Limits] resource limits for element building
      # @param issues [Array, nil] optional issues collector for recording build problems
      # rubocop:disable Metrics/ParameterLists -- per-operation + build context
      # @param [Object, nil] element_builder
      def initialize(name, binding_operation, port_type_operation,
                     documents:, schemas:, limits:, issues: nil, element_builder: nil)
        @name = name
        @binding_operation = binding_operation
        @port_type_operation = port_type_operation
        @documents = documents
        @schemas = schemas
        @limits = limits
        @issues = issues
        @element_builder = element_builder
      end
      # rubocop:enable Metrics/ParameterLists

      # @return [String] the name of this operation
      attr_reader :name

      # Returns the SOAP action for this operation.
      #
      # The SOAP action is typically used as an HTTP header value to indicate
      # the intent of the SOAP request.
      #
      # @return [String, nil] the SOAP action URI, or nil if not specified
      def soap_action
        @binding_operation.soap_action
      end

      # Returns the SOAP version for this operation.
      #
      # @return [String, nil] the SOAP version ('1.1' or '1.2'), or nil if unknown
      def soap_version
        case @binding_operation.soap_namespace
        when NS::WSDL_SOAP_1_1 then '1.1'
        when NS::WSDL_SOAP_1_2 then '1.2'
        end
      end

      # Returns the input message definition for this operation.
      #
      # The input contains the header and body parts that define the
      # structure of request messages.
      #
      # @return [Input] the input message definition
      def input
        @input ||= Input.new(
          @binding_operation, @port_type_operation,
          documents: @documents, schemas: @schemas,
          limits: @limits, issues: @issues,
          element_builder: @element_builder
        )
      end

      # Returns the output message definition for this operation.
      #
      # The output contains the header and body parts that define the
      # structure of response messages. Returns nil for one-way operations
      # that have no output message.
      #
      # @return [Output, nil] the output message definition, or nil for one-way operations
      def output
        return @output if defined?(@output)

        return unless @port_type_operation.output

        @output = Output.new(
          @binding_operation, @port_type_operation,
          documents: @documents, schemas: @schemas,
          limits: @limits, issues: @issues,
          element_builder: @element_builder
        )
      end

      # Returns whether the binding operation defines an input element.
      #
      # @return [Boolean] true if the binding has an +<input>+ element
      def input?
        @binding_operation.input?
      end

      # Returns the RPC input namespace from the binding's input body.
      #
      # @return [String, nil] the namespace URI, or nil if not specified
      def rpc_input_namespace
        @binding_operation.input_body[:namespace]
      end

      # Returns the RPC output namespace from the binding's output body.
      #
      # @return [String, nil] the namespace URI, or nil if not specified
      def rpc_output_namespace
        @binding_operation.output_body[:namespace]
      end

      # Returns the input style for this operation.
      #
      # The style is a combination of the binding style and use attribute,
      # such as 'document/literal' or 'rpc/literal'.
      #
      # @return [String] the input style (e.g., 'document/literal')
      def input_style
        "#{@binding_operation.style}/#{@binding_operation.input_body[:use]}"
      end

      # Returns the output style for this operation.
      #
      # The style is a combination of the binding style and use attribute,
      # such as 'document/literal' or 'rpc/literal'. Returns nil for
      # one-way operations that have no output message.
      #
      # @return [String, nil] the output style, or nil for one-way operations
      def output_style
        use = @binding_operation.output_body[:use]
        return unless use

        "#{@binding_operation.style}/#{use}"
      end
    end
  end
end
