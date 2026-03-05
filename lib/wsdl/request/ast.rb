# frozen_string_literal: true

module WSDL
  module Request
    # Root node of the request AST.
    class AST
      def initialize
        @header = []
        @body = []
        @namespace_decls = []
        @annotations = []
      end

      # @return [Array<Node>]
      attr_reader :header

      # @return [Array<Node>]
      attr_reader :body

      # @return [Array<NamespaceDecl>]
      attr_reader :namespace_decls

      # @return [Array<Hash{Symbol => Object}>]
      attr_reader :annotations

      # Returns namespace URI for a given prefix.
      #
      # @param prefix [String]
      # @return [String, nil]
      def namespace_uri_for(prefix)
        decl = @namespace_decls.find { |d| d.prefix == prefix }
        decl&.uri
      end

      # Returns a Hash representation of namespace declarations.
      #
      # @return [Hash{String => String}]
      def namespaces_hash
        @namespace_decls.to_h { |decl| [decl.prefix || '', decl.uri] }
      end
    end

    # Element node in request AST.
    class Node
      # @param name [String]
      # @param prefix [String, nil]
      # @param local_name [String]
      # @param namespace_uri [String, nil]
      def initialize(name:, prefix:, local_name:, namespace_uri: nil)
        @name = name
        @prefix = prefix
        @local_name = local_name
        @namespace_uri = namespace_uri
        @attributes = []
        @children = []
        @namespace_decls = []
        @resolved_element = nil
      end

      # @return [String]
      attr_reader :name

      # @return [String, nil]
      attr_reader :prefix

      # @return [String]
      attr_reader :local_name

      # @return [String, nil]
      attr_accessor :namespace_uri

      # @return [Array<Attribute>]
      attr_reader :attributes

      # @return [Array<Node,TextNode,CDataNode,Comment,ProcessingInstruction>]
      attr_reader :children

      # @return [Array<NamespaceDecl>]
      attr_reader :namespace_decls

      # @return [WSDL::XML::Element, nil]
      attr_accessor :resolved_element
    end

    # Namespace declaration node.
    NamespaceDecl = Data.define(:prefix, :uri)

    # Text node.
    TextNode = Data.define(:content)

    # CDATA node.
    CDataNode = Data.define(:content)

    # XML comment node.
    Comment = Data.define(:text)

    # XML processing instruction node.
    ProcessingInstruction = Data.define(:target, :content)

    # Element attribute.
    Attribute = Data.define(:name, :prefix, :local_name, :value, :namespace_uri)
  end
end
