# frozen_string_literal: true

module WSDL
  module Schema
    # Utilities for working with XML qualified names (QNames).
    #
    # A QName consists of an optional namespace prefix and a local name,
    # written as "prefix:localName" or just "localName" if no prefix.
    #
    # @example
    #   class MyClass
    #     include Schema::QName
    #
    #     def resolve_type(qname, namespaces)
    #       local, namespace = expand_qname(qname, namespaces)
    #       # ... lookup type by namespace and local name
    #     end
    #   end
    #
    module QName
      # Splits a qualified name into local name and prefix.
      #
      # @param qname [String] the qualified name ("prefix:localName" or "localName")
      # @return [Array(String, String, nil)] tuple of [localName, prefix]
      #
      # @example With prefix
      #   split_qname("tns:User")  # => ["User", "tns"]
      #
      # @example Without prefix
      #   split_qname("User")      # => ["User", nil]
      #
      def split_qname(qname)
        qname.split(':').reverse
      end

      # Expands a qualified name to local name and namespace URI.
      #
      # @param qname [String] the qualified name ("prefix:localName" or "localName")
      # @param namespaces [Hash<String, String>] namespace declarations (xmlns:prefix => URI)
      # @param default_namespace [String, nil] namespace to use when no prefix present
      # @return [Array(String, String, nil)] tuple of [localName, namespaceURI]
      #
      # @example With prefix
      #   namespaces = { "xmlns:tns" => "http://example.com" }
      #   expand_qname("tns:User", namespaces)
      #   # => ["User", "http://example.com"]
      #
      # @example Without prefix, using default namespace
      #   namespaces = { "xmlns" => "http://example.com" }
      #   expand_qname("User", namespaces)
      #   # => ["User", "http://example.com"]
      #
      # @example Without prefix, with explicit default
      #   expand_qname("User", {}, "http://example.com")
      #   # => ["User", "http://example.com"]
      #
      def expand_qname(qname, namespaces, default_namespace = nil)
        local, prefix = split_qname(qname)

        namespace = if prefix
          namespaces["xmlns:#{prefix}"]
        else
          namespaces['xmlns'] || default_namespace
        end

        [local, namespace]
      end
    end
  end
end
