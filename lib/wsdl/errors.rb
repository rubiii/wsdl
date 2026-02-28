# frozen_string_literal: true

class WSDL
  # Base error class for all WSDL-related errors.
  #
  # All custom exceptions raised by this library inherit from this class,
  # making it easy to rescue all WSDL errors with a single rescue clause.
  #
  # @example Rescuing all WSDL errors
  #   begin
  #     wsdl = WSDL.new('http://example.com/service?wsdl')
  #     operation = wsdl.operation('Service', 'Port', 'Operation')
  #     operation.call
  #   rescue WSDL::Error => e
  #     puts "WSDL error: #{e.message}"
  #   end
  #
  class Error < RuntimeError
  end

  # Raised when an operation uses an unsupported SOAP style.
  #
  # Currently, rpc/encoded style operations are not supported.
  # Document/literal and rpc/literal styles are supported.
  #
  # @example
  #   begin
  #     operation = wsdl.operation('Service', 'Port', 'LegacyOperation')
  #   rescue WSDL::UnsupportedStyleError => e
  #     puts "Operation style not supported: #{e.message}"
  #   end
  #
  class UnsupportedStyleError < Error
  end

  # Raised when a relative schema import/include cannot be resolved.
  #
  # This typically occurs when loading a WSDL from inline XML that contains
  # relative schemaLocation references. Relative paths require a base location
  # (file path or URL) to resolve against.
  #
  # @example
  #   begin
  #     # This will fail if the inline XML has relative imports
  #     wsdl = WSDL.new('<definitions>...</definitions>')
  #   rescue WSDL::UnresolvableImportError => e
  #     puts "Cannot resolve import: #{e.message}"
  #   end
  #
  class UnresolvableImportError < Error
  end
end
