# frozen_string_literal: true

module WSDL
  module Security
    class Verifier
      # Base class for verifier components providing shared functionality.
      #
      # All verifier components inherit from this class to get:
      # - Error collection and reporting
      # - XML namespace constants
      # - Common validation patterns
      #
      # @abstract Subclass and implement {#valid?} to create a validator.
      #
      # @example Creating a custom validator
      #   class MyValidator < Verifier::Base
      #     def initialize(document)
      #       super()
      #       @document = document
      #     end
      #
      #     def valid?
      #       return add_failure('Something is wrong') unless check_something
      #       true
      #     end
      #   end
      #
      class Base
        # Local aliases for namespace constants
        SecurityNS = Constants::NS::Security

        # Alias for XML Signature namespace constants.
        #
        # @return [Module]
        SignatureNS = Constants::NS::Signature

        # Alias for SOAP namespace constants.
        #
        # @return [Module]
        SOAPNS = Constants::NS::SOAP

        # SOAP namespace URIs for both versions.
        SOAP_NAMESPACES = [SOAPNS::V1_1, SOAPNS::V1_2].freeze

        # Pattern for valid XML element IDs (NCName production).
        # This prevents XPath injection by rejecting IDs containing quotes,
        # brackets, operators, or other characters that could alter XPath semantics.
        #
        # Used by the Verifier and all sub-validators as the canonical validation
        # pattern for element IDs before interpolation into XPath expressions.
        #
        # @return [Regexp]
        # @see https://www.w3.org/TR/xml-id/
        VALID_ID_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_.-]*\z/

        # @return [Array<String>] errors encountered during validation
        attr_reader :errors

        # Creates a new validator instance.
        def initialize
          @errors = []
        end

        # Returns whether the validation passed.
        #
        # @abstract Subclasses must implement this method.
        # @return [Boolean] true if validation passed
        def valid?
          raise NotImplementedError, "#{self.class} must implement #valid?"
        end

        private

        # Namespace mappings for XPath queries.
        #
        # @return [Hash{String => String}] prefix to URI mappings
        def ns
          {
            'ds' => SignatureNS::DS,
            'wsse' => SecurityNS::WSSE,
            'wsu' => SecurityNS::WSU,
            'soap' => SOAPNS::V1_1,
            'soap12' => SOAPNS::V1_2
          }
        end

        # Records an error and returns false.
        #
        # This is a convenience method for validation checks:
        #   return add_failure('message') unless condition
        #
        # @param message [String] the error message
        # @return [false] always returns false
        def add_failure(message)
          @errors << message
          false
        end

        # Records an error and returns nil.
        #
        # Useful when a method needs to return nil on failure:
        #   return add_failure_nil('message') unless value
        #
        # @param message [String] the error message
        # @return [nil] always returns nil
        def add_failure_nil(message)
          @errors << message
          nil
        end

        # Checks if an element has a SOAP namespace.
        #
        # @param element [Nokogiri::XML::Element] the element to check
        # @return [Boolean] true if element has SOAP 1.1 or 1.2 namespace
        def soap_namespace?(element)
          SOAP_NAMESPACES.include?(element.namespace&.href)
        end
      end
    end
  end
end
