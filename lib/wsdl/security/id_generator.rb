# frozen_string_literal: true

require 'securerandom'

class WSDL
  module Security
    # Utility module for generating unique WS-Security element IDs.
    #
    # This provides a consistent way to generate unique identifiers for
    # WS-Security elements like Timestamp, UsernameToken, and BinarySecurityToken.
    #
    # @example Generate a Timestamp ID
    #   IdGenerator.for('Timestamp')
    #   # => "Timestamp-550e8400-e29b-41d4-a716-446655440000"
    #
    # @example Generate a UsernameToken ID
    #   IdGenerator.for('UsernameToken')
    #   # => "UsernameToken-6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    #
    module IdGenerator
      # Generates a unique ID with the given prefix.
      #
      # The ID is generated using a UUID v4, which provides sufficient
      # uniqueness for WS-Security message elements.
      #
      # @param prefix [String] the prefix for the ID (e.g., 'Timestamp', 'UsernameToken')
      # @return [String] a unique identifier in the format "prefix-uuid"
      #
      # @example
      #   IdGenerator.for('Body')
      #   # => "Body-123e4567-e89b-12d3-a456-426614174000"
      #
      def self.for(prefix)
        "#{prefix}-#{SecureRandom.uuid}"
      end
    end
  end
end
