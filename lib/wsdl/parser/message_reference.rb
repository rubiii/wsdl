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
        # @return [MessageReference] parsed reference
        def from_node(node)
          message = node['message']
          default_namespace = QualifiedName.document_namespace(node.document.root)
          message_name = message ? QualifiedName.parse(message, namespaces: node.namespaces, default_namespace:) : nil

          new(name: node['name'], message:, message_name:)
        end
      end
    }
  end
end
