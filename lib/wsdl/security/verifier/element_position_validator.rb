# frozen_string_literal: true

require_relative 'base'

module WSDL
  module Security
    class Verifier
      # Validates that signed elements are in their expected structural positions.
      #
      # This validator implements W3C XML Signature Best Practice 14:
      # "When checking a reference URI, don't just check the name of the element.
      # Check both the name and position of the element."
      #
      # Different elements have different expected locations in a SOAP message:
      # - Body must be a direct child of Envelope
      # - Timestamp must be within the Security header
      # - WS-Addressing headers must be within the SOAP Header
      #
      # @example Validating an element
      #   validator = ElementPositionValidator.new(element)
      #   if validator.valid?
      #     # Element is in expected position
      #   else
      #     puts validator.errors
      #   end
      #
      # @see https://www.w3.org/TR/xmldsig-bestpractices/#:~:text=Best%20Practice%2014
      #
      class ElementPositionValidator < Base
        # Known security elements that legitimately live in the Security header.
        KNOWN_SECURITY_ELEMENTS = %w[
          Timestamp
          BinarySecurityToken
          UsernameToken
          Signature
          SecurityTokenReference
        ].freeze

        # Creates a new element position validator.
        #
        # @param element [Nokogiri::XML::Element] the element to validate
        def initialize(element)
          super()
          @element = element
        end

        # Validates the element is in its expected structural position.
        #
        # @return [Boolean] true if position is valid
        def valid?
          case @element.name
          when 'Body'
            body_position_valid?
          when 'Timestamp'
            timestamp_position_valid?
          when *Constants::WS_ADDRESSING_HEADERS
            addressing_header_position_valid?
          else
            general_position_valid?
          end
        end

        private

        # Validates the Body element is a direct child of the SOAP Envelope.
        #
        # @return [Boolean] true if position is valid
        def body_position_valid?
          parent = @element.parent

          return true if parent && parent.name == 'Envelope' && soap_namespace?(parent)

          add_failure('Body element must be a direct child of soap:Envelope (possible signature wrapping attack)')
        end

        # Validates the Timestamp element is within the Security header.
        #
        # @return [Boolean] true if position is valid
        def timestamp_position_valid?
          return true if within_security_header?

          add_failure('Timestamp element must be within wsse:Security header (possible signature wrapping attack)')
        end

        # Validates a WS-Addressing header is within the SOAP Header.
        #
        # @return [Boolean] true if position is valid
        def addressing_header_position_valid?
          return true if within_soap_header?

          add_failure("WS-Addressing header '#{@element.name}' must be within soap:Header " \
                      '(possible signature wrapping attack)')
        end

        # Validates general elements are not in suspicious locations.
        #
        # Elements should generally not be hidden inside the Security header
        # unless they're security-related (Timestamp, BinarySecurityToken, etc).
        #
        # @return [Boolean] true if position is acceptable
        def general_position_valid?
          return true if known_security_element?
          return true unless hidden_in_security_header?

          add_failure("Element '#{@element.name}' found in unexpected location within Security header " \
                      '(possible signature wrapping attack)')
        end

        # Checks if the element is within the Security header.
        #
        # @return [Boolean] true if element has a Security ancestor
        def within_security_header?
          @element.ancestors.any? { |a| a.name == 'Security' && a.namespace&.href == SecurityNS::WSSE }
        end

        # Checks if the element is within the SOAP Header.
        #
        # @return [Boolean] true if element has a Header ancestor
        def within_soap_header?
          @element.ancestors.any? { |a| a.name == 'Header' && soap_namespace?(a) }
        end

        # Checks if the element is a known security element.
        #
        # @return [Boolean] true if element is a standard security element
        def known_security_element?
          KNOWN_SECURITY_ELEMENTS.include?(@element.name)
        end

        # Checks if the element is hidden inside the Security header.
        #
        # @return [Boolean] true if element is within Security but not within Signature
        def hidden_in_security_header?
          security_ancestor = find_security_ancestor
          return false unless security_ancestor

          !within_signature_element?
        end

        # Finds the Security header ancestor if present.
        #
        # @return [Nokogiri::XML::Element, nil] the Security element or nil
        def find_security_ancestor
          @element.ancestors.find { |a| a.name == 'Security' && a.namespace&.href == SecurityNS::WSSE }
        end

        # Checks if the element is within a Signature element.
        #
        # Elements within ds:Signature (like KeyInfo contents) are expected.
        #
        # @return [Boolean] true if element is within a Signature
        def within_signature_element?
          @element.ancestors.any? { |a| a.name == 'Signature' && a.namespace&.href == SignatureNS::DS }
        end
      end
    end
  end
end
