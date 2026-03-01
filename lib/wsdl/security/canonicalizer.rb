# frozen_string_literal: true

require 'nokogiri'

module WSDL
  module Security
    # Handles XML Canonicalization (C14N) for digital signatures.
    #
    # Canonicalization transforms XML into a standard form before
    # signing or digesting. This ensures that semantically equivalent
    # XML documents produce the same byte representation.
    #
    # This class wraps Nokogiri's C14N support, which uses libxml2.
    #
    # @example Basic usage
    #   canonicalizer = Canonicalizer.new
    #   canonical_xml = canonicalizer.canonicalize(node)
    #
    # @example With inclusive namespaces
    #   canonicalizer = Canonicalizer.new(algorithm: :exclusive_1_0)
    #   canonical_xml = canonicalizer.canonicalize(node, inclusive_namespaces: ['soap', 'wsu'])
    #
    # @see https://www.w3.org/TR/xml-exc-c14n/
    # @see https://www.w3.org/TR/xml-c14n/
    # @see https://www.w3.org/TR/xml-c14n11/
    #
    class Canonicalizer
      include Constants

      # Supported canonicalization algorithms.
      #
      # Each algorithm specifies:
      # - :id - The URI used in XML SignedInfo/Transform elements
      # - :mode - The Nokogiri constant for canonicalization
      # - :with_comments - Whether to preserve comments
      #
      ALGORITHMS = {
        # Exclusive XML Canonicalization 1.0 (most common for WS-Security)
        exclusive_1_0: {
          id: EXC_C14N_URI,
          mode: Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0,
          with_comments: false
        },

        # Exclusive XML Canonicalization 1.0 with comments
        exclusive_1_0_with_comments: {
          id: "#{EXC_C14N_URI}#WithComments",
          mode: Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0,
          with_comments: true
        },

        # Inclusive XML Canonicalization 1.0
        inclusive_1_0: {
          id: C14N_URI,
          mode: Nokogiri::XML::XML_C14N_1_0,
          with_comments: false
        },

        # Inclusive XML Canonicalization 1.0 with comments
        inclusive_1_0_with_comments: {
          id: "#{C14N_URI}#WithComments",
          mode: Nokogiri::XML::XML_C14N_1_0,
          with_comments: true
        },

        # Inclusive XML Canonicalization 1.1
        inclusive_1_1: {
          id: C14N_11_URI,
          mode: Nokogiri::XML::XML_C14N_1_1,
          with_comments: false
        },

        # Inclusive XML Canonicalization 1.1 with comments
        inclusive_1_1_with_comments: {
          id: "#{C14N_11_URI}#WithComments",
          mode: Nokogiri::XML::XML_C14N_1_1,
          with_comments: true
        }
      }.freeze

      # Default algorithm to use
      DEFAULT_ALGORITHM = :exclusive_1_0

      # Returns the current algorithm configuration.
      # @return [Hash] the algorithm settings
      attr_reader :algorithm

      # Creates a new Canonicalizer instance.
      #
      # @param algorithm [Symbol] the canonicalization algorithm to use
      #   (default: :exclusive_1_0)
      #
      # @raise [ArgumentError] if an unknown algorithm is specified
      #
      def initialize(algorithm: DEFAULT_ALGORITHM)
        @algorithm = ALGORITHMS[algorithm] or
          raise ArgumentError, "Unknown canonicalization algorithm: #{algorithm.inspect}. " \
                               "Valid options: #{ALGORITHMS.keys.join(', ')}"
      end

      # Canonicalizes an XML node.
      #
      # @param node [Nokogiri::XML::Node, Nokogiri::XML::Document] the node to canonicalize
      # @param inclusive_namespaces [Array<String>, nil] namespace prefixes to include
      #   in the canonicalized output (only applicable for exclusive canonicalization)
      #
      # @return [String] the canonicalized XML as a string
      #
      # @example Canonicalize a node
      #   doc = WSDL::XML::Parser.parse('<root><child>text</child></root>')
      #   canonicalizer.canonicalize(doc.root)
      #   # => "<root><child>text</child></root>"
      #
      # @example With inclusive namespaces
      #   canonicalizer.canonicalize(node, inclusive_namespaces: ['soap'])
      #
      def canonicalize(node, inclusive_namespaces: nil)
        node.canonicalize(@algorithm[:mode], inclusive_namespaces, @algorithm[:with_comments])
      end

      # Returns the algorithm URI for use in XML SignedInfo elements.
      #
      # @return [String] the canonicalization algorithm URI
      #
      def algorithm_id
        @algorithm[:id]
      end

      # Returns the Nokogiri canonicalization mode constant.
      #
      # @return [Integer] the Nokogiri C14N mode
      #
      def mode
        @algorithm[:mode]
      end

      # Returns whether this algorithm preserves comments.
      #
      # @return [Boolean] true if comments are preserved
      #
      def with_comments?
        @algorithm[:with_comments]
      end

      # Returns whether this is an exclusive canonicalization algorithm.
      #
      # Exclusive canonicalization only includes namespace declarations
      # that are visibly used in the canonicalized content, unless
      # explicitly listed in the inclusive namespaces list.
      #
      # @return [Boolean] true if using exclusive canonicalization
      #
      def exclusive?
        @algorithm[:mode] == Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0
      end

      # Class method to canonicalize with default settings.
      #
      # @param node [Nokogiri::XML::Node] the node to canonicalize
      # @param options [Hash] options passed to {#initialize} and {#canonicalize}
      #
      # @return [String] the canonicalized XML
      #
      def self.canonicalize(node, **options)
        algorithm = options.delete(:algorithm) || DEFAULT_ALGORITHM
        new(algorithm: algorithm).canonicalize(node, **options)
      end
    end
  end
end
