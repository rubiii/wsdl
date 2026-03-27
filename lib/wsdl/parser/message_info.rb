# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a WSDL message element.
    #
    # A message in WSDL defines the abstract structure of data being
    # exchanged. It consists of one or more parts, each of which may
    # reference an XML Schema type or element.
    #
    # @api private
    #
    class MessageInfo
      # Creates a new MessageInfo from a WSDL message XML node.
      #
      # @param message_node [Nokogiri::XML::Node] the wsdl:message element
      def initialize(message_node)
        @message_node = message_node
      end

      # Returns the name of this message.
      #
      # @return [String] the message name
      def name
        @message_node['name']
      end

      # Returns the parts defined in this message.
      #
      # Each part is a Hash with the following keys:
      # - `:name` - the part name
      # - `:type` - the qualified type name (if using type attribute)
      # - `:element` - the qualified element name (if using element attribute)
      # - `:namespaces` - the namespace declarations in scope
      #
      # @return [Array<Hash>] the message parts
      def parts
        @parts ||= parts!
      end

      private

      # Parses and returns all parts from the message node.
      #
      # All wsdl:part children inherit the same namespace scope from
      # the parent wsdl:message element, so we resolve it once and
      # share the frozen hash across every part.
      #
      # @return [Array<Hash>] the parsed parts
      def parts!
        namespaces = @message_node.namespaces.freeze
        parts = []

        @message_node.element_children.each do |part|
          next unless part.name == 'part'

          parts << {
            name: part['name'],
            type: part['type'],
            element: part['element'],
            namespaces:
          }
        end

        parts
      end
    end
  end
end
