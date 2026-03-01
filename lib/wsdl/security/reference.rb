# frozen_string_literal: true

module WSDL
  module Security
    # Represents a signed reference in an XML Digital Signature.
    #
    # A Reference identifies an element to be signed and contains its
    # computed digest value. References are collected during the signing
    # process and included in the SignedInfo element.
    #
    # @example Creating a reference
    #   reference = Reference.new(
    #     id: 'Body-abc123',
    #     digest_value: 'base64_digest_here'
    #   )
    #
    # @example With inclusive namespaces
    #   reference = Reference.new(
    #     id: 'Body-abc123',
    #     digest_value: 'base64_digest_here',
    #     inclusive_namespaces: ['soap', 'wsu']
    #   )
    #
    # @see https://www.w3.org/TR/xmldsig-core1/#sec-Reference
    #
    class Reference
      # Returns the element ID (without the # prefix).
      # @return [String]
      attr_reader :id

      # Returns the Base64-encoded digest value.
      # @return [String]
      attr_reader :digest_value

      # Returns the list of namespace prefixes for inclusive canonicalization.
      # @return [Array<String>, nil]
      attr_reader :inclusive_namespaces

      # Creates a new Reference instance.
      #
      # @param id [String] the wsu:Id of the referenced element
      # @param digest_value [String] the Base64-encoded digest of the canonicalized element
      # @param inclusive_namespaces [Array<String>, nil] namespace prefixes for C14N
      #
      def initialize(id:, digest_value:, inclusive_namespaces: nil)
        @id = id
        @digest_value = digest_value
        @inclusive_namespaces = inclusive_namespaces
      end

      # Returns the URI reference for use in the Reference element.
      #
      # @return [String] the URI with # prefix (e.g., '#Body-abc123')
      #
      def uri
        "##{@id}"
      end

      # Returns whether this reference has inclusive namespaces specified.
      #
      # @return [Boolean] true if inclusive namespaces are present
      #
      def inclusive_namespaces?
        @inclusive_namespaces&.any? || false
      end

      # Returns the inclusive namespaces as a space-separated string.
      #
      # This is the format required for the PrefixList attribute in
      # the InclusiveNamespaces element.
      #
      # @return [String, nil] the prefix list or nil if no namespaces
      #
      def prefix_list
        return nil unless inclusive_namespaces?

        @inclusive_namespaces.join(' ')
      end

      # Returns a Hash representation of the reference.
      #
      # @return [Hash] the reference data as a hash
      #
      def to_h
        {
          id: @id,
          digest_value: @digest_value,
          inclusive_namespaces: @inclusive_namespaces
        }
      end

      # Compares two references for equality.
      #
      # @param other [Reference] the other reference
      # @return [Boolean] true if references are equal
      #
      def ==(other)
        return false unless other.is_a?(Reference)

        @id == other.id &&
          @digest_value == other.digest_value &&
          @inclusive_namespaces == other.inclusive_namespaces
      end
      alias eql? ==

      # Returns a hash code for the reference.
      #
      # @return [Integer] the hash code
      #
      def hash
        [@id, @digest_value, @inclusive_namespaces].hash
      end
    end
  end
end
