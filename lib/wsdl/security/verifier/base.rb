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
        include Constants

        # SOAP namespace URIs for both versions.
        SOAP_NAMESPACES = [NS_SOAP_1_1, NS_SOAP_1_2].freeze

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
            'ds' => NS_DS,
            'wsse' => NS_WSSE,
            'wsu' => NS_WSU,
            'soap' => NS_SOAP_1_1,
            'soap12' => NS_SOAP_1_2
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
