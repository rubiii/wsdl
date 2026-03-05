# frozen_string_literal: true

module WSDL
  # Formatting utilities for human-readable output.
  #
  # Provides module functions for formatting values in error messages,
  # inspect output, and logs.
  #
  # @example Formatting byte sizes
  #   WSDL::Formatting.format_bytes(10 * 1024 * 1024)  # => "10MB"
  #   WSDL::Formatting.format_bytes(nil)               # => "unlimited"
  #
  module Formatting
    module_function

    # Formats a byte count for human-readable display.
    #
    # Converts byte counts to appropriate units (B, KB, MB) for readability.
    # Returns 'unlimited' for nil values, which represent disabled limits.
    #
    # @param bytes [Integer, nil] the byte count to format
    # @return [String] formatted string (e.g., "10MB", "512KB", "256B", "unlimited")
    #
    # @example Formatting various sizes
    #   Formatting.format_bytes(10 * 1024 * 1024)  # => "10MB"
    #   Formatting.format_bytes(512 * 1024)        # => "512KB"
    #   Formatting.format_bytes(256)               # => "256B"
    #   Formatting.format_bytes(nil)               # => "unlimited"
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
