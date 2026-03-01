# frozen_string_literal: true

require_relative 'base'
require_relative 'element_position_validator'
require 'wsdl/security/secure_compare'
require 'wsdl/security/canonicalizer'
require 'wsdl/security/digester'
require 'wsdl/security/algorithm_mapper'

module WSDL
  module Security
    class Verifier
      # Validates ds:Reference elements by verifying digests of signed content.
      #
      # This validator performs per-reference validation including:
      # - Finding referenced elements by ID
      # - Validating element positions (XSW protection)
      # - Computing and comparing digests using timing-safe comparison
      #
      # @example Validating references
      #   validator = ReferenceValidator.new(document, signed_info_node)
      #   if validator.valid?
      #     puts "All #{validator.reference_count} references verified"
      #   else
      #     puts validator.errors
      #   end
      #
      # @see https://www.w3.org/TR/xmldsig-core1/#sec-Reference
      #
      class ReferenceValidator < Base
        # Pattern for valid XML element IDs (NCName production).
        # This prevents XPath injection by rejecting IDs containing quotes,
        # brackets, operators, or other characters that could alter XPath semantics.
        #
        # @see https://www.w3.org/TR/xml-id/
        VALID_ID_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_.-]*\z/

        # Creates a new reference validator.
        #
        # @param document [Nokogiri::XML::Document] the SOAP document
        # @param signed_info_node [Nokogiri::XML::Element] the ds:SignedInfo element
        def initialize(document, signed_info_node)
          super()
          @document = document
          @signed_info_node = signed_info_node
        end

        # Validates all references in the SignedInfo element.
        #
        # @return [Boolean] true if all references are valid
        def valid?
          references.all? { |ref| validate_single_reference(ref) }
        end

        # Returns the number of references being validated.
        #
        # @return [Integer] the reference count
        def reference_count
          references.size
        end

        # Returns the IDs of all referenced elements.
        #
        # @return [Array<String>] element IDs (without # prefix)
        def referenced_ids
          references.filter_map { |ref| extract_reference_id(ref) }
        end

        private

        # Returns all ds:Reference elements from SignedInfo.
        #
        # @return [Nokogiri::XML::NodeSet] the Reference elements
        def references
          @references ||= @signed_info_node&.xpath('ds:Reference', ns) || []
        end

        # Validates a single reference element.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @return [Boolean] true if the reference is valid
        def validate_single_reference(ref)
          ref_data = extract_reference_data(ref)
          return false unless ref_data

          element = find_and_validate_element(ref_data[:id])
          return add_failure("Referenced element not found: #{ref_data[:uri]}") unless element

          verify_digest(element, ref_data)
        end

        # Extracts data from a Reference element.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @return [Hash, nil] reference data or nil on error
        def extract_reference_data(ref)
          uri = ref['URI']
          return add_failure_nil('Reference missing URI attribute') unless uri

          expected = extract_digest_value(ref, uri)
          return nil unless expected

          digest_alg = extract_digest_algorithm(ref, uri)
          return nil unless digest_alg

          {
            uri:,
            id: uri.delete_prefix('#'),
            expected:,
            digest_alg:,
            c14n_alg: extract_canonicalization_algorithm(ref)
          }
        end

        # Extracts the DigestValue from a Reference.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @param uri [String] the reference URI for error messages
        # @return [String, nil] the digest value or nil on error
        def extract_digest_value(ref, uri)
          value = ref.at_xpath('ds:DigestValue', ns)&.text
          return value if value

          add_failure_nil("Reference missing DigestValue: #{uri}")
        end

        # Extracts the DigestMethod algorithm from a Reference.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @param uri [String] the reference URI for error messages
        # @return [String, nil] the algorithm URI or nil on error
        def extract_digest_algorithm(ref, uri)
          alg = ref.at_xpath('ds:DigestMethod/@Algorithm', ns)&.value
          return alg if alg

          add_failure_nil("Reference missing DigestMethod: #{uri}")
        end

        # Extracts the canonicalization algorithm from a Reference.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @return [String] the algorithm URI (defaults to Exclusive C14N)
        def extract_canonicalization_algorithm(ref)
          ref.at_xpath('ds:Transforms/ds:Transform/@Algorithm', ns)&.value || EXC_C14N_URI
        end

        # Finds an element by ID and validates its structural position.
        #
        # @param id [String] the element ID to find
        # @return [Nokogiri::XML::Element, nil] the element if found and valid
        def find_and_validate_element(id)
          element = find_element_by_id(id)
          return nil unless element
          return nil unless validate_element_position(element)

          element
        end

        # Finds an element by its ID attribute.
        #
        # @param id [String] the element ID
        # @return [Nokogiri::XML::Element, nil] the element or nil if not found
        def find_element_by_id(id)
          return nil unless valid_element_id?(id)

          @document.at_xpath("//*[@wsu:Id='#{id}']", ns) ||
            @document.at_xpath("//*[@Id='#{id}']") ||
            @document.at_xpath("//*[@xml:id='#{id}']")
        end

        # Validates that an element ID is safe to use in XPath queries.
        #
        # This prevents XPath injection attacks by ensuring IDs contain only
        # characters allowed in XML NCName.
        #
        # @param id [String, nil] the element ID to validate
        # @return [Boolean] true if the ID is valid and safe
        def valid_element_id?(id)
          return add_failure('Reference URI is empty') if id.nil? || id.empty?
          return true if id.match?(VALID_ID_PATTERN)

          add_failure("Invalid element ID format (possible XPath injection): #{id.inspect}")
        end

        # Validates an element's structural position using ElementPositionValidator.
        #
        # @param element [Nokogiri::XML::Element] the element to validate
        # @return [Boolean] true if position is valid
        def validate_element_position(element)
          validator = ElementPositionValidator.new(element)
          return true if validator.valid?

          @errors.concat(validator.errors)
          false
        end

        # Verifies the digest of an element matches the expected value.
        #
        # Uses timing-safe comparison to prevent timing attacks.
        #
        # @param element [Nokogiri::XML::Element] the signed element
        # @param ref_data [Hash] the reference data including expected digest
        # @return [Boolean] true if digest matches
        def verify_digest(element, ref_data)
          computed = compute_digest(element, ref_data[:c14n_alg], ref_data[:digest_alg])
          return true if SecureCompare.equal?(computed, ref_data[:expected])

          add_failure("Digest mismatch for #{ref_data[:uri]}")
        end

        # Computes the digest of an element.
        #
        # @param element [Nokogiri::XML::Element] the element to digest
        # @param c14n_alg [String] the canonicalization algorithm URI
        # @param digest_alg [String] the digest algorithm URI
        # @return [String] the Base64-encoded digest
        def compute_digest(element, c14n_alg, digest_alg)
          canonicalizer = Canonicalizer.new(algorithm: AlgorithmMapper.c14n_algorithm(c14n_alg))
          digester = Digester.new(algorithm: AlgorithmMapper.digest_algorithm(digest_alg))
          digester.base64_digest(canonicalizer.canonicalize(element))
        end

        # Extracts the reference ID from a URI attribute.
        #
        # @param ref [Nokogiri::XML::Element] the ds:Reference element
        # @return [String, nil] the ID without # prefix
        def extract_reference_id(ref)
          uri = ref['URI']
          uri&.delete_prefix('#')
        end
      end
    end
  end
end
