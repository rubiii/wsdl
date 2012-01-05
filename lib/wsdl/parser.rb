%w(node definition message part).each do |lib|
  require File.expand_path("../#{lib}", __FILE__)
end

module WSDL
  class Parser

    def initialize(document)
      @document = document
    end

    attr_reader :document

    def parse
      parse_definition(document.root)
    end

  private

    def parse_definition(definition_node)
      definition = Definition.new

      definition.name = definition_node["name"]
      definition.target_namespace = definition_node["targetNamespace"]
      definition.namespaces = definition_node.namespaces

      definition_node.children.select(&:element?).each do |child|
        node = Node.new(child.namespace.href, child.name)

        # TODO: check that the namespace matches the wsdl namespace
        case node.type
          when "message" then definition.messages << parse_message(child, definition)
          else                puts "not implemented. parse_definition for: #{child.name}"
        end
      end

      definition
    end

    def parse_message(message_node, definition)
      message = Message.new
      message.name = message_node["name"]

      message_node.children.select(&:element?).each do |child|
        node = Node.new(child.namespace.href, child.name)

        # may include one of [documentation, part]
        case node.type
          when "part" then message.parts << parse_part(child, definition)
          else             puts "not implemented. parse_message for: #{child.name}"
        end
      end

      message
    end

    def parse_part(part_node, definition)
      part = Part.new

      part.name = part_node["name"]
      part.element_name = part_node["element"]
      part.type_name = part_node["type"]

      # TODO: skip DOCUMENTATION nodes for now
      #part_node.children.select(&:element?).each do |child|
        # may include a documentation node
      #end

      part
    end

  end
end
