# frozen_string_literal: true

module WSDL
  module Request
    # Wraps request body nodes in an RPC operation element for RPC/literal style.
    #
    # Per SOAP 1.1 §7.1 and WS-I Basic Profile §4.7.10, an RPC/literal request
    # wraps its body parts in an element named after the operation, qualified
    # with the namespace from `soap:body/@namespace`.
    #
    # @api private
    class RPCWrapper
      # @param operation_name [String] the WSDL operation name
      # @param namespace_uri [String, nil] the soap:body namespace (may be nil)
      def initialize(operation_name:, namespace_uri:)
        @operation_name = operation_name
        @namespace_uri = namespace_uri
      end

      # Wraps the document's body nodes in an RPC wrapper element.
      #
      # Returns the document unchanged if wrapping is not needed
      # (empty body or already wrapped).
      #
      # @param document [Request::Envelope]
      # @return [Request::Envelope]
      def wrap(document)
        return document if document.body.empty?
        return document if already_wrapped?(document.body)

        build_wrapped_document(document)
      end

      private

      def already_wrapped?(body_nodes)
        body_nodes.length == 1 && body_nodes.first.local_name == @operation_name
      end

      def build_wrapped_document(document)
        wrapped = Envelope.new
        wrapped.namespace_decls.concat(document.namespace_decls)
        wrapped.header.concat(document.header)
        wrapped.body << build_wrapper(document.body)
        wrapped
      end

      def build_wrapper(children)
        wrapper = Node.new(
          name: @operation_name,
          prefix: nil,
          local_name: @operation_name,
          namespace_uri: @namespace_uri
        )
        wrapper.children.concat(children)
        wrapper
      end
    end
  end
end
