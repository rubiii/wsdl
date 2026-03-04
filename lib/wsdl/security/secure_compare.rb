# frozen_string_literal: true

module WSDL
  module Security
    # Provides timing-safe comparison utilities for cryptographic values.
    #
    # Standard string comparison (`==`) short-circuits on the first differing
    # character, which leaks timing information about how many characters match.
    # This can be exploited in timing attacks to gradually guess secret values
    # by measuring response times.
    #
    # This module wraps Ruby's `OpenSSL.secure_compare` to provide constant-time
    # string comparison that prevents such attacks.
    #
    # @example Comparing digest values
    #   computed_digest = compute_digest(element)
    #   expected_digest = reference[:expected]
    #
    #   if SecureCompare.equal?(computed_digest, expected_digest)
    #     puts "Digest verified!"
    #   end
    #
    # @see https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html#compare-password-hashes-using-safe-functions
    # @see https://ruby-doc.org/3.2.0/exts/openssl/OpenSSL.html#method-c-secure_compare
    #
    module SecureCompare
      module_function

      # Performs a timing-safe comparison of two strings.
      #
      # This method uses `OpenSSL.secure_compare` which:
      # 1. Hashes both inputs with SHA-256 to normalize lengths
      # 2. Uses constant-time comparison on the hashes
      # 3. Performs a final equality check
      #
      # This ensures the comparison time is independent of:
      # - How many characters match
      # - The length of either string
      #
      # @param expected [String] first string to compare (typically the expected value)
      # @param actual [String] second string to compare (typically the computed value)
      # @return [Boolean] true if strings are equal, false otherwise
      #
      # @example Basic usage
      #   SecureCompare.equal?("secret123", "secret123")  # => true
      #   SecureCompare.equal?("secret123", "secret456")  # => false
      #
      # @example With Base64-encoded digests
      #   SecureCompare.equal?(expected_digest, computed_digest)
      #
      def equal?(expected, actual)
        return false unless expected.is_a?(String) && actual.is_a?(String)

        OpenSSL.secure_compare(expected, actual)
      end
    end
  end
end
