# frozen_string_literal: true

module WSDL
  # Shared formatting utilities for human-readable output.
  #
  # This module provides helper methods for formatting values in error messages,
  # inspect output, and logs. It can be included in classes that need these utilities.
  #
  # @example Including in a class
  #   class MyClass
  #     include WSDL::Formatting
  #
  #     def display_size(bytes)
  #       format_bytes(bytes)
  #     end
  #   end
  #
  module Formatting
    # Formats a byte count for human-readable display.
    #
    # Converts byte counts to appropriate units (B, KB, MB) for readability.
    # Returns 'unlimited' for nil values, which represent disabled limits.
    #
    # @param bytes [Integer, nil] the byte count to format
    # @return [String] formatted string (e.g., "10MB", "512KB", "256B", "unlimited")
    #
    # @example Formatting various sizes
    #   format_bytes(10 * 1024 * 1024)  # => "10MB"
    #   format_bytes(512 * 1024)        # => "512KB"
    #   format_bytes(256)               # => "256B"
    #   format_bytes(nil)               # => "unlimited"
    #
    def format_bytes(bytes)
      return 'unlimited' if bytes.nil?

      if bytes >= 1024 * 1024
        "#{bytes / (1024 * 1024)}MB"
      elsif bytes >= 1024
        "#{bytes / 1024}KB"
      else
        "#{bytes}B"
      end
    end
  end
end
