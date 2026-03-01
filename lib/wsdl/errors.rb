# frozen_string_literal: true

module WSDL
  # Base error class for all WSDL-related errors.
  #
  # All custom exceptions raised by this library inherit from this class,
  # making it easy to rescue all WSDL errors with a single rescue clause.
  #
  # @example Rescuing all WSDL errors
  #   begin
  #     client = WSDL::Client.new('http://example.com/service?wsdl')
  #     operation = client.operation('Service', 'Port', 'Operation')
  #     operation.call
  #   rescue WSDL::Error => e
  #     puts "WSDL error: #{e.message}"
  #   end
  #
  class Error < StandardError
  end

  # Raised when an operation uses an unsupported SOAP style.
  #
  # Currently, rpc/encoded style operations are not supported.
  # Document/literal and rpc/literal styles are supported.
  #
  # @example
  #   begin
  #     operation = client.operation('Service', 'Port', 'LegacyOperation')
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
  #     client = WSDL::Client.new('<definitions>...</definitions>')
  #   rescue WSDL::UnresolvableImportError => e
  #     puts "Cannot resolve import: #{e.message}"
  #   end
  #
  class UnresolvableImportError < Error
  end

  # Raised when signature verification fails on a response.
  #
  # This error is raised when:
  # - The response does not contain a signature when one is expected
  # - The signature verification process fails
  # - The digest values do not match the signed content
  #
  # @example
  #   begin
  #     response.verify_signature!
  #   rescue WSDL::SignatureVerificationError => e
  #     log_security_event("Signature verification failed: #{e.message}")
  #   end
  #
  class SignatureVerificationError < Error
  end

  # Raised when XML parsing detects a potential security attack.
  #
  # This error wraps security-related XML parsing failures detected by
  # libxml2, such as:
  #
  # - Entity amplification attacks (Billion Laughs / XML bomb)
  # - Excessive document depth
  # - Other security limit violations
  #
  # The original Nokogiri error is preserved as the cause for debugging.
  #
  # @example Catching XML security attacks
  #   begin
  #     doc = WSDL::XML::Parser.parse(untrusted_xml)
  #   rescue WSDL::XMLSecurityError => e
  #     logger.warn("XML attack blocked: #{e.message}")
  #   end
  #
  # @example Accessing the original error
  #   begin
  #     doc = WSDL::XML::Parser.parse(untrusted_xml)
  #   rescue WSDL::XMLSecurityError => e
  #     puts e.cause # => #<Nokogiri::XML::SyntaxError: ...>
  #   end
  #
  class XMLSecurityError < Error
  end
end
