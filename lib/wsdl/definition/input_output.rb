# frozen_string_literal: true

class WSDL
  class Definition
    # Represents the input message definition for an operation.
    #
    # This class processes the binding and port type operation definitions
    # to build the header and body parts that define the structure of
    # request messages. It resolves message references and builds XML
    # element definitions that can be used to construct SOAP envelopes.
    #
    # @api private
    #
    class Input
      # Creates a new Input instance.
      #
      # @param binding_operation [BindingOperation] the binding operation with protocol details
      # @param port_type_operation [PortTypeOperation] the port type operation with interface details
      # @param wsdl [Definition] the parent WSDL definition for resolving references
      def initialize(binding_operation, port_type_operation, wsdl)
        @binding_operation = binding_operation
        @port_type_operation = port_type_operation
        @wsdl = wsdl

        build_parts
      end

      # The header part elements for this input message.
      #
      # These elements define the structure of the SOAP header
      # that should be sent with the request.
      #
      # @return [Array<XML::Element>] the header part elements
      attr_reader :header_parts

      # The body part elements for this input message.
      #
      # These elements define the structure of the SOAP body
      # that should be sent with the request.
      #
      # @return [Array<XML::Element>] the body part elements
      attr_reader :body_parts

      private

      # Builds the header and body parts from the operation definitions.
      #
      # Resolves message references from the port type operation and
      # builds XML element definitions. Header parts that are explicitly
      # defined in the binding are removed from the body parts.
      #
      # @return [void]
      def build_parts
        body_parts = collect_body_parts
        header_parts = collect_header_parts

        # remove explicit header parts from the body parts
        header_part_names = header_parts.map { |part| part[:name] }
        body_parts.reject! do |part|
          header_part_names.include? part[:name]
        end

        @header_parts = XML::ElementBuilder.new(@wsdl.schemas).build(header_parts)
        @body_parts = XML::ElementBuilder.new(@wsdl.schemas).build(body_parts)
      end

      # Collects the body parts from the referenced message.
      #
      # @return [Array<Hash>] the body part definitions
      def collect_body_parts
        find_message(message_name).parts
      end

      # Returns the message name for the input.
      #
      # @return [String] the qualified message name
      def message_name
        @port_type_operation.input[:message]
      end

      # Collects the header parts from explicitly defined header references.
      #
      # Each header in the binding may reference a different message
      # and part, allowing headers to be defined separately from
      # the main input message.
      #
      # @return [Array<Hash>] the header part definitions
      def collect_header_parts
        parts = []

        headers.each do |header|
          next unless header[:message] && header[:part]

          message_parts = find_message(header[:message]).parts

          # only add the single header part from the message
          parts << message_parts.find { |part| part[:name] == header[:part] }
        end

        parts
      end

      # Returns the header definitions from the binding operation.
      #
      # @return [Array<Hash>] the header definitions
      def headers
        @binding_operation.input_headers
      end

      # Finds a message by its qualified name.
      #
      # @param qname [String] the qualified message name (prefix:localName)
      # @return [Message] the message object
      # @raise [RuntimeError] if the message cannot be found
      def find_message(qname)
        local = qname.split(':').last

        @wsdl.documents.messages[local] or
          raise "Unable to find message #{qname.inspect}"
      end
    end

    # Represents the output message definition for an operation.
    #
    # This class extends {Input} to process output (response) messages
    # instead of input (request) messages. It overrides the message
    # and header accessors to reference the output definitions.
    #
    # @api private
    #
    class Output < Input
      private

      # Returns the message name for the output.
      #
      # @return [String] the qualified message name
      def message_name
        @port_type_operation.output[:message]
      end

      # Returns the header definitions from the binding operation output.
      #
      # @return [Array<Hash>] the output header definitions
      def headers
        @binding_operation.output_headers
      end
    end
  end
end
