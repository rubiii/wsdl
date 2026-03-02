# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a soap:header/soap12:header message reference.
    #
    # @api private
    HeaderReference = Data.define(:encoding_style, :namespace, :use, :message, :part, :message_name) {
      class << self
        # Builds a header reference from a SOAP header node.
        #
        # @param header_node [Nokogiri::XML::Node] soap:header or soap12:header node
        # @return [HeaderReference] parsed header reference
        def from_node(header_node)
          message = header_node['message']
          default_namespace = QualifiedName.document_namespace(header_node.document.root)
          message_name = if message
            QualifiedName.parse(message, namespaces: header_node.namespaces, default_namespace:)
          end

          new(
            encoding_style: header_node['encodingStyle'],
            namespace: header_node['namespace'],
            use: header_node['use'],
            message:,
            part: header_node['part'],
            message_name:
          )
        end
      end
    }
  end
end
