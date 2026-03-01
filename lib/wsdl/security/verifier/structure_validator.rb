# frozen_string_literal: true

require_relative 'base'

module WSDL
  module Security
    class Verifier
      # Validates SOAP document structure to prevent XML Signature Wrapping (XSW) attacks.
      #
      # This validator implements structural checks recommended by the W3C XML Signature
      # Best Practices specification. These checks run before expensive cryptographic
      # operations to catch attacks early.
      #
      # == Protections
      #
      # - *Duplicate ID Detection* — Rejects documents with duplicate wsu:Id, Id, or xml:id
      #   attributes, preventing attackers from injecting elements with the same ID as
      #   signed elements.
      #
      # - *Signature Location Validation* — Ensures the ds:Signature element is within the
      #   wsse:Security header as required by WS-Security SOAP Message Security specification.
      #
      # @example Basic usage
      #   validator = StructureValidator.new(document)
      #   if validator.valid?
      #     # Document structure is safe, proceed with crypto verification
      #   else
      #     puts validator.errors
      #   end
      #
      # @see https://www.w3.org/TR/xmldsig-bestpractices/
      # @see https://docs.oasis-open.org/wss-m/wss/v1.1.1/os/wss-SOAPMessageSecurity-v1.1.1-os.html
      #
      class StructureValidator < Base
        # Creates a new structure validator.
        #
        # @param document [Nokogiri::XML::Document] the SOAP document to validate
        def initialize(document)
          super()
          @document = document
        end

        # Validates the document structure for XSW attack indicators.
        #
        # @return [Boolean] true if structure is valid
        def valid?
          return add_failure('No signature found in document') unless signature_present?
          return false unless no_duplicate_ids?
          return false unless signature_in_security_header?

          true
        end

        # Returns whether a signature is present in the document.
        #
        # @return [Boolean] true if a ds:Signature element exists
        def signature_present?
          !signature_node.nil?
        end

        # Returns the signature node.
        #
        # @return [Nokogiri::XML::Element, nil] the ds:Signature element
        def signature_node
          @signature_node ||= @document.at_xpath('//ds:Signature', ns)
        end

        # Returns the security header node.
        #
        # @return [Nokogiri::XML::Element, nil] the wsse:Security element
        def security_node
          @security_node ||= @document.at_xpath('//wsse:Security', ns)
        end

        private

        # Validates there are no duplicate element IDs.
        #
        # Duplicate IDs are a common indicator of XSW attacks where attackers
        # inject elements with the same ID as signed elements.
        #
        # @return [Boolean] true if no duplicates found
        def no_duplicate_ids?
          ids = collect_all_element_ids
          duplicates = find_duplicates(ids)

          return true if duplicates.empty?

          add_failure("Duplicate element IDs detected (possible signature wrapping attack): #{duplicates.join(', ')}")
        end

        # Collects all ID attributes from the document.
        #
        # @return [Array<String>] all wsu:Id, Id, and xml:id values
        def collect_all_element_ids
          id_nodes = @document.xpath('//*[@wsu:Id] | //*[@Id] | //*[@xml:id]', ns)

          id_nodes.flat_map do |node|
            [
              node.attribute_with_ns('Id', SecurityNS::WSU)&.value,
              node['Id'],
              node.attribute_with_ns('id', 'http://www.w3.org/XML/1998/namespace')&.value
            ].compact
          end
        end

        # Finds duplicate values in an array.
        #
        # @param array [Array<String>] values to check
        # @return [Array<String>] duplicate values
        def find_duplicates(array)
          array.group_by(&:itself)
            .select { |_, occurrences| occurrences.size > 1 }
            .keys
        end

        # Validates the Signature element is within the Security header.
        #
        # Per WS-Security SOAP Message Security specification, the ds:Signature
        # element MUST be a child of the wsse:Security header.
        #
        # @return [Boolean] true if signature is properly located
        def signature_in_security_header?
          sig = signature_node
          parent = sig.parent

          return true if parent && parent.name == 'Security' && parent.namespace&.href == SecurityNS::WSSE

          add_failure('Signature element must be within wsse:Security header (possible signature wrapping attack)')
        end
      end
    end
  end
end
