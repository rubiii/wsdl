# frozen_string_literal: true

require 'nokogiri'

module WSDL
  module Security
    # Helper for building XML with or without explicit namespace prefixes.
    #
    # Some SOAP servers have strict XML parsers that only accept elements
    # with explicit namespace prefixes (e.g., `ds:Signature` instead of
    # `Signature xmlns="..."`). This helper provides a unified interface
    # for building XML that works in both modes.
    #
    # @example Building with default namespaces
    #   helper = XmlBuilderHelper.new(explicit_prefixes: false)
    #   helper.build_element(xml, :ds, 'Signature') do
    #     helper.build_child(xml, :ds, 'SignedInfo')
    #   end
    #   # => <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    #   #      <SignedInfo/>
    #   #    </Signature>
    #
    # @example Building with explicit prefixes
    #   helper = XmlBuilderHelper.new(explicit_prefixes: true)
    #   helper.build_element(xml, :ds, 'Signature') do
    #     helper.build_child(xml, :ds, 'SignedInfo')
    #   end
    #   # => <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
    #   #      <ds:SignedInfo/>
    #   #    </ds:Signature>
    #
    class XmlBuilderHelper
      include Constants

      # Namespace prefix to URI mapping
      NAMESPACE_URIS = {
        ds: NS_DS,
        wsse: NS_WSSE,
        wsu: NS_WSU,
        ec: NS_EC
      }.freeze

      # Returns whether explicit namespace prefixes are enabled.
      # @return [Boolean]
      attr_reader :explicit_prefixes

      # Creates a new XmlBuilderHelper instance.
      #
      # @param explicit_prefixes [Boolean] whether to use explicit namespace prefixes
      #
      def initialize(explicit_prefixes: false)
        @explicit_prefixes = explicit_prefixes
      end

      # Builds a root element with namespace declaration.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @param ns_prefix [Symbol] the namespace prefix (:ds, :wsse, :wsu, :ec)
      # @param element_name [String, Symbol] the element name
      # @param attributes [Hash] additional attributes
      # @yield the block for building child elements
      #
      def build_element(xml, ns_prefix, element_name, attributes = {}, &)
        invoke(xml, ns_prefix, element_name, ns_attributes(ns_prefix).merge(attributes), &)
      end

      # Builds a child element (inherits namespace from parent).
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @param ns_prefix [Symbol] the namespace prefix (:ds, :wsse, :wsu, :ec)
      # @param element_name [String, Symbol] the element name
      # @param content_or_attributes [String, Hash, nil] text content or attributes
      # @param attributes [Hash] attributes (when content is provided)
      # @yield the block for building child elements
      #
      def build_child(xml, ns_prefix, element_name, content_or_attributes = nil, attributes = {}, &)
        content, attrs = resolve_arguments(content_or_attributes, attributes)
        invoke(xml, ns_prefix, element_name, attrs, content, &)
      end

      # Builds a child element with explicit namespace declaration.
      #
      # @param xml [Nokogiri::XML::Builder] the XML builder
      # @param ns_prefix [Symbol] the namespace prefix
      # @param element_name [String, Symbol] the element name
      # @param attributes [Hash] additional attributes
      # @yield the block for building child elements
      #
      def build_child_with_ns(xml, ns_prefix, element_name, attributes = {}, &)
        invoke(xml, ns_prefix, element_name, ns_attributes(ns_prefix).merge(attributes), &)
      end

      private

      # Returns namespace declaration attributes for the given prefix.
      def ns_attributes(prefix)
        uri = NAMESPACE_URIS[prefix] or raise ArgumentError, "Unknown namespace prefix: #{prefix}"

        @explicit_prefixes ? { "xmlns:#{prefix}" => uri } : { xmlns: uri }
      end

      # Resolves overloaded content/attributes arguments.
      def resolve_arguments(content_or_attributes, attributes)
        if content_or_attributes.is_a?(Hash) && attributes.empty?
          [nil, content_or_attributes]
        else
          [content_or_attributes, attributes]
        end
      end

      # Invokes the XML builder with the appropriate target and arguments.
      def invoke(xml, ns_prefix, element_name, attributes, content = nil, &block)
        target = @explicit_prefixes ? xml[ns_prefix.to_s] : xml

        if content
          target.send(element_name, content, attributes)
        elsif block
          target.send(element_name, attributes, &block)
        else
          target.send(element_name, attributes)
        end
      end
    end
  end
end
