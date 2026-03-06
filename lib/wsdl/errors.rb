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
  #     operation.invoke
  #   rescue WSDL::Error => e
  #     puts "WSDL error: #{e.message}"
  #   end
  #
  class Error < StandardError
  end

  # Base class for non-recoverable WSDL errors.
  #
  # Fatal errors indicate security violations or hard safety constraints
  # that should never be silently skipped.
  #
  # @example
  #   begin
  #     client = WSDL::Client.new(wsdl, strict_schema: false)
  #   rescue WSDL::FatalError => e
  #     logger.error("Fatal WSDL error: #{e.message}")
  #   end
  #
  class FatalError < Error
  end

  # Raised when an imported schema cannot be fetched or parsed.
  #
  # This error wraps recoverable schema import failures (for example missing
  # files, network timeouts, or malformed imported XSD documents).
  #
  # In `strict_schema: false` mode these errors are logged and skipped.
  # In `strict_schema: true` mode they are raised.
  #
  class SchemaImportError < Error
    # @return [String, nil] schema location that failed
    attr_reader :location

    # @return [String, nil] parent document location used as resolution base
    attr_reader :base_location

    # @return [String, nil] import action (`import` or `include`)
    attr_reader :action

    # Creates a new SchemaImportError.
    #
    # @param message [String] error message
    # @param location [String, nil] schema location that failed
    # @param base_location [String, nil] resolution base location
    # @param action [String, nil] import action (`import` or `include`)
    def initialize(message = nil, location: nil, base_location: nil, action: nil)
      @location = location
      @base_location = base_location
      @action = action
      super(message)
    end
  end

  # Raised when an imported schema cannot be parsed as XML.
  class SchemaImportParseError < SchemaImportError
  end

  # Raised when a WSDL document uses an unsupported WSDL version.
  #
  # Currently only WSDL 1.1 is supported. WSDL 2.0 documents
  # (namespace `http://www.w3.org/ns/wsdl`) are detected and rejected
  # with a clear error message.
  #
  # @example
  #   begin
  #     client = WSDL::Client.new('http://example.com/service?wsdl')
  #   rescue WSDL::UnsupportedWSDLVersionError => e
  #     puts "WSDL version not supported: #{e.message}"
  #   end
  #
  class UnsupportedWSDLVersionError < FatalError
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
  # This occurs when a relative schemaLocation cannot be resolved because the
  # current import context has no resolvable base location (file path or URL).
  #
  # @example
  #   begin
  #     # Relative imports require a resolvable base file/URL location
  #     parser_result = WSDL::Parser::Result.parse('<definitions>...</definitions>', http_adapter)
  #   rescue WSDL::UnresolvableImportError => e
  #     puts "Cannot resolve import: #{e.message}"
  #   end
  #
  class UnresolvableImportError < FatalError
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
  class PathRestrictionError < FatalError
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

  # Base class for response security verification errors.
  #
  # All errors raised during WS-Security response verification inherit
  # from this class, making it easy to rescue all verification failures:
  #
  # @example Rescuing all security verification errors
  #   begin
  #     response.security.verify!
  #   rescue WSDL::SecurityError => e
  #     log_security_event(e.message)
  #   end
  #
  class SecurityError < FatalError
  end

  # Raised when signature verification fails on a response.
  #
  # This error is raised when:
  # - The response does not contain a signature when one is expected
  # - The signature verification process fails
  # - SignedInfo does not reference the SOAP Body
  # - The digest values do not match the signed content
  #
  # @example
  #   begin
  #     response.security.verify_signature!
  #   rescue WSDL::SignatureVerificationError => e
  #     log_security_event("Signature verification failed: #{e.message}")
  #   end
  #
  class SignatureVerificationError < SecurityError
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
  class XMLSecurityError < FatalError
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
  class CertificateValidationError < SecurityError
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
  class TimestampValidationError < SecurityError
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
  class UnsupportedAlgorithmError < SecurityError
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
  class ResourceLimitError < FatalError
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

  # Raised when a WSDL reference cannot be resolved.
  #
  # This error is raised when binding, portType, or message references point
  # to definitions that do not exist in the parsed WSDL document set, or when
  # schema namespaces/components cannot be resolved during message building.
  #
  # @example
  #   begin
  #     operation = client.operation('Service', 'Port', 'Operation')
  #     operation.input
  #   rescue WSDL::UnresolvedReferenceError => e
  #     puts "#{e.reference_type}: #{e.reference_name}"
  #   end
  #
  class UnresolvedReferenceError < Error
    # @return [Symbol, nil] reference type (:binding, :port_type, :message, :message_part)
    attr_reader :reference_type

    # @return [String, nil] unresolved reference name
    attr_reader :reference_name

    # @return [String, nil] namespace associated with the unresolved reference
    attr_reader :namespace

    # @return [String, nil] context where resolution failed
    attr_reader :context

    # Creates a new UnresolvedReferenceError.
    #
    # @param message [String] error message
    # @param reference_type [Symbol, nil] type of reference
    # @param reference_name [String, nil] unresolved reference
    # @param namespace [String, nil] unresolved namespace for schema lookups
    # @param context [String, nil] call-site context
    def initialize(message = nil, reference_type: nil, reference_name: nil, namespace: nil, context: nil)
      @reference_type = reference_type
      @reference_name = reference_name
      @namespace = namespace
      @context = context
      super(message)
    end
  end

  # Raised when duplicate WSDL definitions share the same key.
  #
  # This error is raised when two imported documents define the same component
  # (for example, message/binding/portType) with an identical key.
  #
  class DuplicateDefinitionError < Error
    # @return [Symbol, nil] component type (:message, :port_type, :binding, :service)
    attr_reader :component_type

    # @return [String, nil] duplicate definition key
    attr_reader :definition_key

    # Creates a new DuplicateDefinitionError.
    #
    # @param message [String] error message
    # @param component_type [Symbol, nil] component type
    # @param definition_key [String, nil] duplicate key
    def initialize(message = nil, component_type: nil, definition_key: nil)
      @component_type = component_type
      @definition_key = definition_key
      super(message)
    end
  end

  # Raised when request definition is missing or structurally incomplete.
  #
  # This error is raised when calling an operation that expects input but no
  # request envelope has been defined via {WSDL::Operation#prepare}.
  class RequestDefinitionError < Error
  end

  # Raised when a request violates schema or structural constraints.
  class RequestValidationError < Error
  end

  # Raised when request DSL usage is invalid.
  #
  # Examples include invalid XML names, undeclared QName prefixes,
  # or overriding reserved namespace prefixes.
  class RequestDslError < Error
  end

  # Raised when manual request content conflicts with generated WS-Security.
  #
  # This indicates a hard outbound security configuration error and is treated
  # as non-recoverable.
  class RequestSecurityConflictError < FatalError
  end

  # Raised when an HTTP redirect targets a restricted destination.
  #
  # This error prevents SSRF (Server-Side Request Forgery) attacks where
  # a malicious WSDL endpoint redirects to internal network addresses
  # such as cloud metadata services, loopback interfaces, or RFC 1918
  # private networks.
  #
  # @example Catching unsafe redirects
  #   begin
  #     client = WSDL::Client.new('https://evil.example.com/service?wsdl')
  #   rescue WSDL::UnsafeRedirectError => e
  #     puts "Blocked redirect to: #{e.target_url}"
  #   end
  #
  # @see https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
  #
  class UnsafeRedirectError < FatalError
    # @return [String, nil] the redirect target URL that was blocked
    attr_reader :target_url

    # Creates a new UnsafeRedirectError.
    #
    # @param message [String] error message
    # @param target_url [String, nil] the blocked redirect target
    def initialize(message = nil, target_url: nil)
      @target_url = target_url
      super(message)
    end
  end

  # Raised when the maximum number of HTTP redirects is exceeded.
  #
  # This prevents redirect loops and excessive redirect chains that
  # could be used for denial-of-service attacks.
  class TooManyRedirectsError < FatalError
  end

  # Raised when a sealed collection is mutated.
  #
  # This error indicates internal misuse where a parser collection that has
  # completed its build phase is modified afterward.
  class SealedCollectionError < Error
  end
end
