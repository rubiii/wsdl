# frozen_string_literal: true

module WSDL
  # Represents a fully qualified XML name (QName).
  #
  # A QName consists of a namespace URI and a local name. This value object
  # is used as a stable collection key across imported documents and for
  # resolving type/element/attribute references in schemas.
  #
  # @api private
  QName = Data.define(:namespace, :local) {
    class << self
      # Returns the effective namespace for top-level WSDL components.
      #
      # @param root [Nokogiri::XML::Node] wsdl:definitions root node
      # @return [String, nil] resolved namespace URI
      def document_namespace(root)
        namespace = root['targetNamespace']
        return namespace if namespace && !namespace.empty?

        raise UnresolvedReferenceError.new(
          'WSDL definitions element is missing required targetNamespace',
          reference_type: :namespace,
          reference_name: root.name,
          context: 'wsdl:definitions'
        )
      end

      # Resolves a lexical QName into a namespace/local pair.
      #
      # Returns a lightweight two-element Array instead of allocating a
      # QName instance. Use this on hot paths where only the namespace and
      # local name are needed and the object identity of a QName is not
      # required (e.g. schema lookups that immediately destructure the
      # result).
      #
      # @param qname [String] QName text (for example "tns:MyMessage")
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace for unprefixed names
      # @return [Array(String, String)] [namespace, local] pair
      def resolve(qname, namespaces:, default_namespace: nil)
        colon = qname.rindex(':')

        if colon
          prefix = qname[0, colon]
          local  = qname[(colon + 1)..]
          [namespaces["xmlns:#{prefix}"], local]
        else
          [namespaces['xmlns'] || default_namespace, qname]
        end
      end

      # Parses a lexical QName into a fully qualified name.
      #
      # @param qname [String] QName text (for example "tns:MyMessage")
      # @param namespaces [Hash{String => String}] in-scope namespace declarations
      # @param default_namespace [String, nil] fallback namespace for unprefixed names
      # @return [QName] the resolved qualified name
      def parse(qname, namespaces:, default_namespace: nil)
        raise ArgumentError, 'QName must be a non-empty String' unless qname.is_a?(String) && !qname.empty?

        new(*resolve(qname, namespaces:, default_namespace:))
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
