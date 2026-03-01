# frozen_string_literal: true

require 'builder'

module WSDL
  module Builder
    # Builds SOAP envelopes for operation requests.
    #
    # This class constructs the complete SOAP envelope XML including
    # the header and body sections. It handles namespace registration
    # and supports both document and RPC style operations.
    #
    # @api private
    #
    class Envelope
      # Namespace ID prefix used for registered namespaces.
      NSID = 'lol'

      # Creates a new Envelope instance.
      #
      # @param operation_info [Parser::OperationInfo] the operation definition
      # @param header [Hash, nil] the SOAP header data
      # @param body [Hash, nil] the SOAP body data
      # @param pretty_print [Boolean] whether to format XML with indentation
      def initialize(operation_info, header, body, pretty_print: true)
        @logger = Logging.logger[self]

        @operation_info = operation_info
        @header = header || {}
        @body = body || {}

        @nsid_counter = -1
        @namespaces = {}
        @pretty_print = pretty_print
        @xsi_required = false
      end

      # Returns whether pretty printing is enabled.
      #
      # @return [Boolean] true if XML will be formatted with indentation
      attr_reader :pretty_print

      # Registers a namespace and returns its namespace ID.
      #
      # If the namespace has already been registered, returns the
      # existing namespace ID. Otherwise, creates a new one.
      #
      # @param namespace [String] the namespace URI to register
      # @return [String] the namespace ID (e.g., 'lol0', 'lol1')
      def register_namespace(namespace)
        @namespaces[namespace] ||= create_nsid
      end

      # Marks the XSI namespace as required for this envelope.
      #
      # This should be called when serializing nil values with xsi:nil="true"
      # for nillable elements. The namespace will be added to the envelope element.
      #
      # @return [void]
      def require_xsi_namespace
        @xsi_required = true
      end

      # Returns whether the XSI namespace is required.
      #
      # @return [Boolean] true if xsi namespace should be included
      def xsi_required?
        @xsi_required
      end

      # Builds and returns the complete SOAP envelope XML.
      #
      # @return [String] the SOAP envelope XML string
      def to_s
        build_envelope(build_header, build_body)
      end

      private

      # Creates a new unique namespace ID.
      #
      # @return [String] a new namespace ID
      def create_nsid
        @nsid_counter += 1
        "#{NSID}#{@nsid_counter}"
      end

      # Builds the SOAP header XML.
      #
      # @return [String] the header XML, or empty string if no header data
      def build_header
        return '' if @header.empty?

        Message.new(self, @operation_info.input.header_parts, pretty_print:).build(@header)
      end

      # Builds the SOAP body XML.
      #
      # For RPC-style operations, wraps the body in an additional element.
      #
      # @return [String] the body XML, or empty string if no body data
      def build_body
        return '' if @body.empty?

        body = Message.new(self, @operation_info.input.body_parts, pretty_print:).build(@body)

        if rpc_call?
          build_rpc_wrapper(body)
        else
          body
        end
      end

      # Builds the complete SOAP envelope with header and body.
      #
      # @param header [String] the built header XML
      # @param body [String] the built body XML
      # @return [String] the complete envelope XML
      def build_envelope(header, body)
        builder = @pretty_print ? ::Builder::XmlMarkup.new(indent: 2) : ::Builder::XmlMarkup.new

        builder.tag! :env, :Envelope, collect_namespaces do |xml|
          xml.tag!(:env, :Header) do |xml|
            xml << header
          end
          xml.tag!(:env, :Body) { |xml| xml << body }
        end

        builder.target!
      end

      # Builds the RPC wrapper element around the body content.
      #
      # @param body [String] the body content to wrap
      # @return [String] the wrapped body XML
      def build_rpc_wrapper(body)
        name = @operation_info.name
        namespace = @operation_info.binding_operation.input_body[:namespace]
        nsid = register_namespace(namespace) if namespace

        tag = [nsid, name].compact.join(':')

        format('<%<tag>s>%<body>s</%<tag>s>', tag: tag, body: body)
      end

      # Returns whether this is an RPC-style call.
      #
      # @return [Boolean] true if the operation uses RPC style
      def rpc_call?
        @operation_info.binding_operation.style == 'rpc'
      end

      # Collects all namespaces for the envelope element.
      #
      # Includes all registered namespaces plus the SOAP envelope namespace
      # appropriate for the SOAP version being used.
      #
      # @return [Hash{String => String}] namespace declarations
      def collect_namespaces
        # registered namespaces
        namespaces = @namespaces.each_with_object({}) do |(namespace, nsid), memo|
          memo["xmlns:#{nsid}"] = namespace
        end

        # envelope namespace
        namespaces['xmlns:env'] = case @operation_info.soap_version
        when '1.1' then NS::SOAP_1_1
        when '1.2' then NS::SOAP_1_2
        end

        # XSI namespace (for xsi:nil="true" on nillable elements)
        namespaces['xmlns:xsi'] = NS::XSI if @xsi_required

        namespaces
      end
    end
  end
end
