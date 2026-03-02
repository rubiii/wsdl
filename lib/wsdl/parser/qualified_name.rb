# frozen_string_literal: true

module WSDL
  module Parser
    # Represents a fully qualified WSDL name.
    #
    # WSDL references (e.g. message, binding, portType) are QName values that
    # resolve to a namespace URI and local name. This value object is used as a
    # stable collection key across imported documents.
    #
    # @api private
    QualifiedName = Data.define(:namespace, :local) {
      class << self
        # Returns the effective namespace for top-level WSDL components.
        #
        # Some real-world WSDLs omit targetNamespace and only provide xmlns:tns.
        #
        # @param root [Nokogiri::XML::Node] wsdl:definitions root node
        # @return [String, nil] resolved namespace URI
        def document_namespace(root)
          root['targetNamespace'] || root.namespaces['xmlns:tns'] || root.namespaces['xmlns']
        end

        # Parses a lexical QName into a fully qualified name.
        #
        # @param qname [String] QName text (for example "tns:MyMessage")
        # @param namespaces [Hash{String => String}] in-scope namespace declarations
        # @param default_namespace [String, nil] fallback namespace for unprefixed names
        # @return [QualifiedName] the resolved qualified name
        def parse(qname, namespaces:, default_namespace:)
          raise ArgumentError, 'QName must be a non-empty String' unless qname.is_a?(String) && !qname.empty?

          local, prefix = split(qname)
          namespace = prefix ? namespaces["xmlns:#{prefix}"] : namespaces['xmlns'] || default_namespace

          new(namespace, local)
        end

        private

        # Splits lexical QName into local and prefix.
        #
        # @param qname [String] lexical QName
        # @return [Array(String, String, nil)] [local, prefix]
        def split(qname)
          prefix, separator, local = qname.rpartition(':')
          return [qname, nil] if separator.empty?

          [local, prefix]
        end
      end

      # Returns a readable representation used in errors.
      #
      # @return [String]
      def to_s
        return local unless namespace

        "{#{namespace}}#{local}"
      end
    }
  end
end
