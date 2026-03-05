# frozen_string_literal: true

module WSDL
  module Parser
    # Base class for building message parts (headers and body) from
    # WSDL operation definitions. Subclasses specify the message direction
    # by implementing {#message_reference} and {#headers}.
    #
    # @api private
    #
    class MessageParts
      # Creates a new MessageParts instance.
      #
      # @param binding_operation [BindingOperation] the binding operation with protocol details
      # @param port_type_operation [PortTypeOperation] the port type operation with interface details
      # @param parser_result [Result] the parser result for resolving references
      def initialize(binding_operation, port_type_operation, parser_result)
        @binding_operation = binding_operation
        @port_type_operation = port_type_operation
        @parser_result = parser_result

        build_parts
      end

      # The header part elements for this message.
      #
      # These elements define the structure of the SOAP header.
      #
      # @return [Array<XML::Element>] the header part elements
      attr_reader :header_parts

      # The body part elements for this message.
      #
      # These elements define the structure of the SOAP body.
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

        builder = XML::ElementBuilder.new(@parser_result.schemas, limits: @parser_result.limits)
        @header_parts = builder.build(header_parts)
        @body_parts = builder.build(body_parts)
      end

      # Collects the body parts from the referenced message.
      #
      # @return [Array<Hash>] the body part definitions
      def collect_body_parts
        reference = message_reference
        find_message(reference).parts
      end

      # Returns the message reference for this direction.
      # Subclasses must override to return the input or output reference.
      #
      # @return [MessageReference] parsed message reference
      def message_reference
        raise NotImplementedError
      end

      # Collects the header parts from explicitly defined header references.
      #
      # Each header in the binding may reference a different message
      # and part, allowing headers to be defined separately from
      # the main message.
      #
      # @return [Array<Hash>] the header part definitions
      def collect_header_parts
        headers.each_with_object([]) do |header, parts|
          validate_header_reference!(header)

          message = find_message(header)
          parts << find_header_part(message, header)
        end
      end

      # Validates required soap:header reference attributes.
      #
      # The WSDL SOAP binding requires header references to identify both
      # a message and a part. Missing either makes the contract ambiguous
      # and must fail closed.
      #
      # @param header [HeaderReference] header metadata from the binding
      # @return [void]
      # @raise [UnresolvedReferenceError] when required attributes are missing
      def validate_header_reference!(header)
        if header.message.nil?
          raise UnresolvedReferenceError.new(
            'Unable to resolve soap:header because @message is missing',
            reference_type: :message,
            reference_name: nil,
            context: "soap:header for operation #{@port_type_operation.name.inspect}"
          )
        end

        return if header.part

        raise UnresolvedReferenceError.new(
          "Unable to resolve soap:header part for message #{header.message.inspect} because @part is missing",
          reference_type: :message_part,
          reference_name: nil,
          namespace: header.message_name&.namespace,
          context: "soap:header for operation #{@port_type_operation.name.inspect}"
        )
      end

      # Finds a SOAP header part in a message definition.
      #
      # @param message [MessageInfo] the message that should contain the part
      # @param header [HeaderReference] header metadata from the binding
      # @return [Hash] the resolved message part
      # @raise [UnresolvedReferenceError] if the referenced part does not exist
      def find_header_part(message, header)
        message_part = message.parts.find { |part| part[:name] == header.part }
        return message_part if message_part

        raise UnresolvedReferenceError.new(
          "Unable to find part #{header.part.inspect} in message #{header.message.inspect}",
          reference_type: :message_part,
          reference_name: header.part.to_s,
          namespace: header.message_name&.namespace,
          context: "soap:header for operation #{@port_type_operation.name.inspect}"
        )
      end

      # Returns the header definitions from the binding operation.
      # Subclasses must override to return input or output headers.
      #
      # @return [Array<HeaderReference>] the header definitions
      def headers
        raise NotImplementedError
      end

      # Finds a message by reference metadata.
      #
      # @param reference [MessageReference, HeaderReference] message reference
      # @return [MessageInfo] the message object
      # @raise [UnresolvedReferenceError] if the message cannot be found
      def find_message(reference)
        message_name = reference.message_name
        message = @parser_result.documents.messages[message_name]
        return message if message

        raise UnresolvedReferenceError.new(
          "Unable to find message #{reference.message.inspect}",
          reference_type: :message,
          reference_name: reference.message.to_s,
          context: "operation #{@port_type_operation.name.inspect}"
        )
      end
    end

    # Represents the input message definition for an operation.
    #
    # Processes the binding and port type operation definitions to build
    # the header and body parts for request messages.
    #
    # @api private
    #
    class Input < MessageParts
      private

      # Returns the message reference for the input.
      #
      # @return [MessageReference] parsed message reference
      def message_reference
        @port_type_operation.input
      end

      # Returns the header definitions from the binding operation input.
      #
      # @return [Array<HeaderReference>] the input header definitions
      def headers
        @binding_operation.input_headers
      end
    end

    # Represents the output message definition for an operation.
    #
    # Processes the binding and port type operation definitions to build
    # the header and body parts for response messages.
    #
    # @api private
    #
    class Output < MessageParts
      private

      # Returns the message reference for the output.
      #
      # @return [MessageReference] parsed message reference
      def message_reference
        @port_type_operation.output
      end

      # Returns the header definitions from the binding operation output.
      #
      # @return [Array<HeaderReference>] the output header definitions
      def headers
        @binding_operation.output_headers
      end
    end
  end
end
