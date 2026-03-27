# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a wsdl:input/wsdl:output message reference.
    #
    # @api private
    MessageReference = Data.define(:name, :message, :message_name) {
      class << self
        # Builds a message reference from an input/output node.
        #
        # @param node [Nokogiri::XML::Node] wsdl:input or wsdl:output node
        # @param namespaces [Hash{String => String}, nil] pre-resolved namespace
        #   declarations to avoid repeated Nokogiri namespace lookups on sibling nodes
        # @return [MessageReference] parsed reference
        def from_node(node, namespaces: nil)
          namespaces ||= node.namespaces
          message = node['message']
          default_namespace = QName.document_namespace(node.document.root)
          message_name = message ? QName.parse(message, namespaces:, default_namespace:) : nil

          new(name: node['name'], message:, message_name:)
        end
      end
    }
  end
end
