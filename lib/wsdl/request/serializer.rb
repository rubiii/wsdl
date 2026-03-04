# frozen_string_literal: true

require 'nokogiri'

module WSDL
  module Request
    # Serializes request AST into SOAP envelope XML.
    class Serializer
      def initialize(document:, soap_version:, pretty_print:)
        @document = document
        @soap_version = soap_version
        @pretty_print = pretty_print
      end

      # @return [Nokogiri::XML::Document]
      def to_document
        reset_state!
        envelope = build_envelope
        header, body = build_standard_sections(envelope)
        append_section_nodes!(header, @document.header, envelope)
        append_section_nodes!(body, @document.body, envelope)
        @doc
      end

      # @return [String]
      def serialize
        to_document.root.to_xml(save_with: xml_save_options)
      end

      private

      def reset_state!
        @doc = Nokogiri::XML::Document.new
        @generated_prefix_counter = 0
        @uri_prefix = {}
      end

      def xml_save_options
        save_options = Nokogiri::XML::Node::SaveOptions::AS_XML | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
        save_options |= Nokogiri::XML::Node::SaveOptions::FORMAT if @pretty_print
        save_options
      end

      def build_standard_sections(envelope)
        header = soap_section_node('Header', envelope)
        body = soap_section_node('Body', envelope)
        [header, body]
      end

      def soap_section_node(local_name, envelope)
        section = Nokogiri::XML::Node.new(local_name, @doc)
        section.namespace = envelope.namespace
        envelope.add_child(section)
        section
      end

      def append_section_nodes!(section, nodes, envelope)
        nodes.each do |node|
          section.add_child(build_element(node, envelope))
        end
      end

      def build_envelope
        envelope = Nokogiri::XML::Node.new('Envelope', @doc)
        @doc.root = envelope

        soap_ns = @soap_version == '1.2' ? NS::SOAP_1_2 : NS::SOAP_1_1
        env_ns = envelope.add_namespace_definition('env', soap_ns)
        envelope.namespace = env_ns

        @document.namespaces_hash.each do |prefix, uri|
          namespace = envelope.add_namespace_definition(prefix.empty? ? nil : prefix, uri)
          @uri_prefix[uri] ||= namespace.prefix if namespace.prefix
        end

        envelope
      end

      def build_element(node, envelope)
        xml_node = Nokogiri::XML::Node.new(node.local_name, @doc)
        apply_element_namespace!(xml_node, node, envelope)

        node.attributes.each do |attribute|
          set_attribute!(xml_node, attribute, envelope)
        end

        node.children.each do |child|
          append_child_node!(xml_node, child, envelope)
        end

        xml_node
      end

      def append_child_node!(xml_node, child, envelope)
        serialized = serialized_child_node(child, envelope)
        xml_node.add_child(serialized) if serialized
      end

      def serialized_child_node(child, envelope)
        case child
        when ::WSDL::Request::Node
          build_element(child, envelope)
        when ::WSDL::Request::TextNode
          Nokogiri::XML::Text.new(child.content.to_s, @doc)
        when ::WSDL::Request::CDataNode
          Nokogiri::XML::CDATA.new(@doc, child.content.to_s)
        when ::WSDL::Request::Comment
          Nokogiri::XML::Comment.new(@doc, child.text.to_s)
        when ::WSDL::Request::ProcessingInstruction
          Nokogiri::XML::ProcessingInstruction.new(@doc, child.target.to_s, child.content.to_s)
        end
      end

      def apply_element_namespace!(xml_node, node, envelope)
        return unless node.namespace_uri

        prefix = node.prefix || prefix_for_uri(node.namespace_uri)
        namespace = ensure_namespace!(envelope, prefix, node.namespace_uri)
        xml_node.namespace = namespace
      end

      def set_attribute!(xml_node, attribute, envelope)
        if attribute.namespace_uri
          prefix = attribute.prefix || prefix_for_uri(attribute.namespace_uri)
          ensure_namespace!(envelope, prefix, attribute.namespace_uri)
          xml_node["#{prefix}:#{attribute.local_name}"] = attribute.value.to_s
        else
          xml_node[attribute.local_name] = attribute.value.to_s
        end
      end

      def prefix_for_uri(uri)
        return @uri_prefix[uri] if @uri_prefix.key?(uri)

        generated = next_generated_prefix
        @uri_prefix[uri] = generated
      end

      def next_generated_prefix
        loop do
          prefix = "ns#{@generated_prefix_counter}"
          @generated_prefix_counter += 1
          next if %w[env wsse wsu ds ec xsi soap soap12].include?(prefix)

          return prefix
        end
      end

      def ensure_namespace!(envelope, prefix, uri)
        namespace = envelope.namespace_definitions.find { |ns| ns.prefix == prefix && ns.href == uri }
        return namespace if namespace

        namespace = envelope.add_namespace_definition(prefix, uri)
        @uri_prefix[uri] ||= namespace.prefix if namespace.prefix
        namespace
      end
    end
  end
end
