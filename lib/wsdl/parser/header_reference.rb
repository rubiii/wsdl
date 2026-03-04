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
          message = normalize_required_attribute(header_node['message'])
          part = normalize_required_attribute(header_node['part'])
          default_namespace = QName.document_namespace(header_node.document.root)
          message_name = if message
            QName.parse(message, namespaces: header_node.namespaces, default_namespace:)
          end

          new(
            encoding_style: header_node['encodingStyle'],
            namespace: header_node['namespace'],
            use: header_node['use'],
            message:,
            part:,
            message_name:
          )
        end

        private

        def normalize_required_attribute(value)
          return nil unless value

          normalized = value.strip
          normalized.empty? ? nil : normalized
        end
      end
    }
  end
end
