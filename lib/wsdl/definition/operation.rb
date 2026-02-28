# frozen_string_literal: true

require 'wsdl/definition/input_output'
require 'wsdl/xml/element_builder'

class WSDL
  class Definition
    # Represents a WSDL operation with its binding and port type information.
    #
    # This class combines information from the binding operation (protocol details)
    # and port type operation (abstract interface) to provide a complete view of
    # an operation that can be invoked.
    #
    # @api private
    #
    class Operation
      # Creates a new Operation instance.
      #
      # @param name [String] the operation name
      # @param endpoint [String] the SOAP endpoint URL
      # @param binding_operation [BindingOperation] the binding operation with protocol details
      # @param port_type_operation [PortTypeOperation] the port type operation with interface details
      # @param wsdl [Definition] the parent WSDL definition
      def initialize(name, endpoint, binding_operation, port_type_operation, wsdl)
        @name = name
        @endpoint = endpoint
        @binding_operation = binding_operation
        @port_type_operation = port_type_operation
        @wsdl = wsdl
      end

      # @return [String] the name of this operation
      attr_reader :name

      # @return [String] the SOAP endpoint URL
      attr_reader :endpoint

      # @return [BindingOperation] the binding operation with protocol details
      attr_reader :binding_operation

      # @return [PortTypeOperation] the port type operation with interface details
      attr_reader :port_type_operation

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
        when WSDL::NS_SOAP_1_1 then '1.1'
        when WSDL::NS_SOAP_1_2 then '1.2'
        end
      end

      # Returns the input message definition for this operation.
      #
      # The input contains the header and body parts that define the
      # structure of request messages.
      #
      # @return [Input] the input message definition
      def input
        @input ||= Input.new(@binding_operation, @port_type_operation, @wsdl)
      end

      # Returns the output message definition for this operation.
      #
      # The output contains the header and body parts that define the
      # structure of response messages.
      #
      # @return [Output] the output message definition
      def output
        @output ||= Output.new(@binding_operation, @port_type_operation, @wsdl)
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
      # such as 'document/literal' or 'rpc/literal'.
      #
      # @return [String] the output style (e.g., 'document/literal')
      def output_style
        "#{@binding_operation.style}/#{@binding_operation.output_body[:use]}"
      end
    end
  end
end
