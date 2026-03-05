# frozen_string_literal: true

require 'wsdl/ns'
require 'wsdl/response/fault'
require 'wsdl/response/parser'

module WSDL
  class Response
    # Parses SOAP fault elements from a response document.
    #
    # Handles both SOAP 1.1 and 1.2 fault structures, producing
    # a normalized {Fault} data object.
    #
    # @api private
    class FaultParser
      # Parses a SOAP fault from the given XML document.
      #
      # @param doc [Nokogiri::XML::Document] the parsed response document
      # @return [Fault, nil] the parsed fault, or nil if no fault is present
      def self.parse(doc)
        new(doc).parse
      end

      # @param doc [Nokogiri::XML::Document] the parsed response document
      def initialize(doc)
        @doc = doc
      end

      # @return [Fault, nil] the parsed fault, or nil if no fault is present
      def parse
        node = fault_node
        return unless node

        if node.namespace&.href == NS::SOAP_1_2
          parse_soap_1_2_fault(node)
        else
          parse_soap_1_1_fault(node)
        end
      end

      private

      # @return [Nokogiri::XML::Element, nil] the Fault element
      def fault_node
        @doc.at_xpath(
          '//soap:Fault | //soap12:Fault | //env:Fault',
          'soap' => NS::SOAP_1_1,
          'soap12' => NS::SOAP_1_2,
          'env' => NS::SOAP_1_1
        )
      end

      # @param node [Nokogiri::XML::Element] the Fault element
      # @return [Fault]
      def parse_soap_1_1_fault(node)
        Fault.new(
          code: node.at_xpath('faultcode')&.text,
          subcodes: [],
          reason: node.at_xpath('faultstring')&.text,
          detail: parse_detail(node.at_xpath('detail')),
          node: nil,
          role: node.at_xpath('faultactor')&.text
        )
      end

      # @param node [Nokogiri::XML::Element] the Fault element
      # @return [Fault]
      def parse_soap_1_2_fault(node)
        namespaces = { 'soap12' => NS::SOAP_1_2 }

        Fault.new(
          code: node.at_xpath('soap12:Code/soap12:Value', namespaces)&.text,
          subcodes: collect_subcodes(node.at_xpath('soap12:Code/soap12:Subcode', namespaces), namespaces),
          reason: node.at_xpath('soap12:Reason/soap12:Text', namespaces)&.text,
          detail: parse_detail(node.at_xpath('soap12:Detail', namespaces)),
          node: node.at_xpath('soap12:Node', namespaces)&.text,
          role: node.at_xpath('soap12:Role', namespaces)&.text
        )
      end

      # @param subcode_node [Nokogiri::XML::Element, nil] the Subcode element
      # @param namespaces [Hash{String => String}] namespace mappings
      # @return [Array<String>] subcode values
      def collect_subcodes(subcode_node, namespaces)
        codes = []
        current = subcode_node

        while current
          value = current.at_xpath('soap12:Value', namespaces)&.text
          codes << value if value
          current = current.at_xpath('soap12:Subcode', namespaces)
        end

        codes
      end

      # @param detail_node [Nokogiri::XML::Element, nil] the detail element
      # @return [Hash, nil] parsed detail or nil
      def parse_detail(detail_node)
        return unless detail_node

        children = detail_node.element_children
        return unless children.any?

        Parser.parse(detail_node, unwrap: true)
      end
    end
  end
end
