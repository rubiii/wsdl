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
      # @param documents [DocumentCollection] for resolving message references
      # @param schemas [Schema::Collection] for building element trees
      # @param limits [Limits] resource limits for element building
      # @param issues [Array, nil] optional issues collector for recording build problems
      # rubocop:disable Metrics/ParameterLists -- per-operation + build context
      # @param [Object, nil] element_builder
      def initialize(binding_operation, port_type_operation,
                     documents:, schemas:, limits:, issues: nil, element_builder: nil)
        @binding_operation = binding_operation
        @port_type_operation = port_type_operation
        @documents = documents
        @schemas = schemas
        @limits = limits
        @issues = issues
        @element_builder = element_builder

        build_parts
      end
      # rubocop:enable Metrics/ParameterLists

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
      # Bails out early when the message reference is missing — records
      # one issue and sets empty parts without doing any further work.
      #
      # @return [void]
      def build_parts
        reference = message_reference
        unless reference
          record_issue("Operation #{@port_type_operation.name.inspect} is missing a required message reference")
          @header_parts = []
          @body_parts = []
          return
        end

        body_parts = collect_body_parts(reference)
        header_parts = collect_header_parts

        # remove explicit header parts from the body parts
        header_part_names = header_parts.map { |part| part[:name] }
        body_parts.reject! do |part|
          header_part_names.include?(part[:name])
        end

        builder = @element_builder || XML::ElementBuilder.new(@schemas, limits: @limits, issues: @issues)
        @header_parts = builder.build(header_parts)
        @body_parts = builder.build(body_parts)
      end

      # Collects the body parts from the referenced message.
      #
      # @param reference [MessageReference] the message reference
      # @return [Array<Hash>] the body part definitions
      def collect_body_parts(reference)
        message = find_message(reference)
        return [] unless message

        message.parts
      end

      # Returns the message reference for this direction.
      # Subclasses must override to return the input or output reference.
      #
      # @return [MessageReference, nil] parsed message reference
      def message_reference
        raise NotImplementedError
      end

      # Collects the header parts from explicitly defined header references.
      #
      # Skips headers with missing or invalid references, recording
      # issues instead of raising.
      #
      # @return [Array<Hash>] the header part definitions
      def collect_header_parts
        headers.each_with_object([]) do |header, parts|
          next unless valid_header_reference?(header)

          message = find_message(header)
          next unless message

          part = find_header_part(message, header)
          parts << part if part
        end
      end

      # Validates required soap:header reference attributes.
      #
      # @param header [HeaderReference] header metadata from the binding
      # @return [Boolean] true if the header reference is valid
      def valid_header_reference?(header)
        if header.message.nil?
          record_issue('Unable to resolve soap:header for operation ' \
                       "#{@port_type_operation.name.inspect} because @message is missing")
          return false
        end

        unless header.part
          record_issue('Unable to resolve soap:header part for message ' \
                       "#{header.message.inspect} because @part is missing")
          return false
        end

        true
      end

      # Finds a SOAP header part in a message definition.
      #
      # @param message [MessageInfo] the message that should contain the part
      # @param header [HeaderReference] header metadata from the binding
      # @return [Hash, nil] the resolved message part, or nil if not found
      def find_header_part(message, header)
        message_part = message.parts.find { |part| part[:name] == header.part }
        return message_part if message_part

        record_issue("Unable to find part #{header.part.inspect} in message #{header.message.inspect}")
        nil
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
      # @return [MessageInfo, nil] the message object, or nil if not found
      def find_message(reference)
        message_name = reference.message_name
        message = @documents.messages[message_name]
        return message if message

        record_issue("Unable to find message #{reference.message.inspect} " \
                     "for operation #{@port_type_operation.name.inspect}")
        nil
      end

      # Records a build issue if an issues collector is available.
      #
      # @param error [String] description of the problem
      # @return [void]
      def record_issue(error)
        operation = @port_type_operation.name
        @issues&.push(type: :build_error, operation:, error:)
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
