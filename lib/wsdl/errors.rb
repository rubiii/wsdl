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

  # Raised when a file path violates sandbox restrictions.
  #
  # This occurs when a WSDL or schema import attempts to access files outside
  # the allowed directory tree. This protection prevents path traversal attacks
  # where malicious schemaLocation attributes could read arbitrary system files.
  #
  # @example
  #   begin
  #     # WSDL with malicious import: schemaLocation="../../../../etc/passwd"
  #     client = WSDL::Client.new('/app/wsdl/malicious.wsdl')
  #   rescue WSDL::PathRestrictionError => e
  #     puts "Blocked file access: #{e.message}"
  #   end
  #
  # @see https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
  #
  class PathRestrictionError < Error
  end

  # Raised when an HTTP adapter does not satisfy the required interface.
  #
  # This is raised when custom adapters are missing required methods or return
  # invalid values for required methods.
  #
  # @example
  #   begin
  #     client = WSDL::Client.new(wsdl, http: custom_adapter)
  #   rescue WSDL::InvalidHTTPAdapterError => e
  #     puts "Invalid adapter: #{e.message}"
  #   end
  #
  class InvalidHTTPAdapterError < Error
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
  #     response.security.verify_signature!
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

  # Raised when certificate validation fails during response verification.
  #
  # This error is raised when:
  # - The certificate has expired or is not yet valid
  # - The certificate chain cannot be verified against the trust store
  # - The certificate is self-signed and a trust store rejects it
  #
  # @example Catching certificate validation errors
  #   begin
  #     response.security.verify_signature!
  #   rescue WSDL::CertificateValidationError => e
  #     log_security_event("Untrusted certificate: #{e.message}")
  #   end
  #
  # @example Distinguishing from other signature errors
  #   begin
  #     response.security.verify_signature!
  #   rescue WSDL::CertificateValidationError => e
  #     # Certificate issue (expired, untrusted CA, etc.)
  #     puts "Certificate problem: #{e.message}"
  #   rescue WSDL::SignatureVerificationError => e
  #     # Signature issue (tampered content, wrong key, etc.)
  #     puts "Signature problem: #{e.message}"
  #   end
  #
  class CertificateValidationError < Error
  end

  # Raised when response timestamp validation fails.
  #
  # This error is raised when:
  # - The response timestamp has expired (beyond clock skew tolerance)
  # - The response Created time is too far in the future (clock skew exceeded)
  # - A potential replay attack is detected
  #
  # Timestamp validation helps prevent replay attacks where an attacker
  # captures a valid signed response and replays it later.
  #
  # @example Catching timestamp validation errors
  #   begin
  #     response.security.verify_timestamp!
  #   rescue WSDL::TimestampValidationError => e
  #     log_security_event("Stale or replayed message: #{e.message}")
  #   end
  #
  # @example Distinguishing from signature errors
  #   begin
  #     response.security.verify!
  #   rescue WSDL::TimestampValidationError => e
  #     # Timestamp issue (expired, clock skew, replay)
  #     puts "Timestamp problem: #{e.message}"
  #   rescue WSDL::SignatureVerificationError => e
  #     # Signature issue (tampered content, wrong key, etc.)
  #     puts "Signature problem: #{e.message}"
  #   end
  #
  class TimestampValidationError < Error
  end

  # Raised when an algorithm is not supported or not recognized.
  #
  # This error is raised during signature verification when:
  # - The response specifies an unknown or unsupported algorithm URI
  # - An algorithm downgrade attack may be in progress
  # - A required algorithm parameter is missing
  #
  # This strict validation prevents algorithm confusion attacks where an
  # attacker modifies the algorithm URI to cause verification with the
  # wrong algorithm.
  #
  # @example Catching unsupported algorithm errors
  #   begin
  #     response.security.verify_signature!
  #   rescue WSDL::UnsupportedAlgorithmError => e
  #     log_security_event("Unsupported algorithm: #{e.message}")
  #     log_security_event("Algorithm URI: #{e.algorithm_uri}")
  #     log_security_event("Algorithm type: #{e.algorithm_type}")
  #   end
  #
  # @see https://www.w3.org/TR/xmldsig-bestpractices/
  #
  class UnsupportedAlgorithmError < Error
    # @return [String, nil] the unrecognized algorithm URI
    attr_reader :algorithm_uri

    # @return [Symbol, nil] the type of algorithm (:digest, :signature, :canonicalization)
    attr_reader :algorithm_type

    # Creates a new UnsupportedAlgorithmError.
    #
    # @param message [String] error message
    # @param algorithm_uri [String, nil] the URI that was not recognized
    # @param algorithm_type [Symbol, nil] the type of algorithm
    def initialize(message = nil, algorithm_uri: nil, algorithm_type: nil)
      @algorithm_uri = algorithm_uri
      @algorithm_type = algorithm_type
      super(message)
    end
  end

  # Raised when a resource limit is exceeded.
  #
  # This error protects against denial-of-service attacks from malformed
  # or malicious WSDL documents that could exhaust system resources.
  #
  # @example Catching resource limit errors
  #   begin
  #     client = WSDL::Client.new('http://example.com/huge.wsdl')
  #   rescue WSDL::ResourceLimitError => e
  #     puts "Limit exceeded: #{e.limit_name}"
  #     puts "Limit: #{e.limit_value}, Actual: #{e.actual_value}"
  #   end
  #
  # @example Handling specific limits
  #   begin
  #     client = WSDL::Client.new(wsdl_url)
  #   rescue WSDL::ResourceLimitError => e
  #     case e.limit_name
  #     when :max_document_size
  #       puts "Document too large"
  #     when :max_schemas
  #       puts "Too many schema imports"
  #     end
  #   end
  #
  class ResourceLimitError < Error
    # @return [Symbol] the name of the limit that was exceeded
    attr_reader :limit_name

    # @return [Integer] the configured limit value
    attr_reader :limit_value

    # @return [Integer] the actual value that exceeded the limit
    attr_reader :actual_value

    # Creates a new ResourceLimitError.
    #
    # @param message [String] error message
    # @param limit_name [Symbol] the name of the limit (e.g., :max_document_size)
    # @param limit_value [Integer] the configured limit
    # @param actual_value [Integer] the value that exceeded the limit
    def initialize(message = nil, limit_name: nil, limit_value: nil, actual_value: nil)
      @limit_name = limit_name
      @limit_value = limit_value
      @actual_value = actual_value
      super(message)
    end
  end
end
