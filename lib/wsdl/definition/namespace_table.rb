# frozen_string_literal: true

module WSDL
  class Definition
    # Frozen lookup table that maps integer indices to namespace URI strings.
    #
    # The namespace table is built during Definition construction from the
    # +namespaces+ array in the serialized data. Definition uses it internally
    # to resolve namespace indices before passing data to consumers.
    #
    # @api private
    #
    class NamespaceTable
      # @param uris [Array<String>] ordered namespace URI strings
      def initialize(uris)
        @uris = uris
        freeze
      end

      # Resolves a namespace index to its URI string.
      #
      # @param index [Integer] zero-based namespace index
      # @return [String] the namespace URI
      # @raise [KeyError] if the index is out of range
      def resolve(index)
        @uris.fetch(index) { raise KeyError, "namespace index #{index} not found in namespace table" }
      end

      # Returns the underlying array for serialization.
      #
      # @return [Array<String>] namespace URIs in index order
      def to_a
        @uris
      end
    end
  end
end
