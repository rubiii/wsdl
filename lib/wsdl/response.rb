# frozen_string_literal: true

require_relative 'xml_hash'
require_relative 'response_parser'

class WSDL
  # Represents a SOAP response from an operation call.
  #
  # This class wraps the raw HTTP response and provides methods
  # for parsing and accessing the SOAP envelope contents. When
  # schema information is available, response values are automatically
  # converted to appropriate Ruby types and arrays are handled
  # consistently based on the schema's maxOccurs definitions.
  #
  # @example Accessing the response body
  #   response = operation.call
  #   puts response.body[:get_user_response][:user][:name]
  #
  # @example Working with the raw response
  #   response = operation.call
  #   puts response.raw  # Raw XML string
  #
  # @example Using XPath queries
  #   response = operation.call
  #   users = response.xpath('//ns:User', 'ns' => 'http://example.com/users')
  #   users.each { |user| puts user.text }
  #
  # @example Type conversions (with schema)
  #   response = operation.call
  #   response.body[:order][:id]       # => 123 (Integer, not "123")
  #   response.body[:order][:total]    # => BigDecimal("99.99")
  #   response.body[:order][:shipped]  # => true (Boolean, not "true")
  #   response.body[:order][:items]    # => [{ name: "Widget" }] (always Array)
  #
  # @example Verifying signature
  #   response = operation.call
  #   if response.signature_present?
  #     if response.signature_valid?
  #       puts "Response is signed and valid"
  #       puts "Signed elements: #{response.signed_elements}"
  #     else
  #       puts "Signature verification failed: #{response.signature_errors}"
  #     end
  #   end
  #
  class Response
    # Creates a new Response instance.
    #
    # @param raw_response [String] the raw HTTP response body (XML)
    # @param output_parts [Array<WSDL::XML::Element>, nil] optional schema elements
    #   describing the expected response structure for type-aware parsing
    # @param verify_certificate [OpenSSL::X509::Certificate, nil] optional certificate
    #   to use for signature verification instead of extracting from message
    def initialize(raw_response, output_parts: nil, verify_certificate: nil)
      @raw_response = raw_response
      @output_parts = output_parts
      @verify_certificate = verify_certificate
      @verifier = nil
    end

    # Returns the raw XML response string.
    #
    # @return [String] the raw XML response body
    def raw
      @raw_response
    end

    # Returns the parsed SOAP body as a Hash.
    #
    # When schema information is available (output_parts), values are
    # automatically converted to appropriate Ruby types:
    # - xsd:int, xsd:integer, xsd:long → Integer
    # - xsd:decimal → BigDecimal
    # - xsd:float, xsd:double → Float
    # - xsd:boolean → true/false
    # - xsd:date → Date
    # - xsd:dateTime → Time
    # - xsd:base64Binary → decoded String
    #
    # Elements with maxOccurs > 1 are always returned as Arrays,
    # even when only one element is present.
    #
    # @return [Hash] the parsed body content
    # @example
    #   response.body
    #   # => { GetUserResponse: { User: { Name: "John", Age: 30 } } }
    def body
      @body ||= if @output_parts
        ResponseParser.new(@output_parts).parse(doc)
      else
        hash[:Envelope][:Body]
      end
    end
    alias to_hash body

    # Returns the parsed SOAP header as a Hash.
    #
    # The header is extracted from the SOAP envelope and returned
    # with symbolized keys preserving the original element names.
    #
    # @return [Hash, nil] the parsed header content, or nil if empty
    def header
      hash[:Envelope][:Header]
    end

    # Returns the entire parsed SOAP envelope as a Hash.
    #
    # Keys are symbolized, preserving original element names.
    # Note: This method does not use schema-aware parsing.
    # Use {#body} for schema-aware access to the response body.
    #
    # @return [Hash] the complete parsed envelope
    def hash
      @hash ||= XmlHash.parse(doc)
    end

    # Returns the response as a Nokogiri XML document.
    #
    # Use this when you need full XML manipulation capabilities
    # or want to run XPath queries.
    #
    # @return [Nokogiri::XML::Document] the parsed XML document
    def doc
      @doc ||= Nokogiri.XML(raw)
    end

    # Executes an XPath query on the response document.
    #
    # @param path [String] the XPath expression
    # @param namespaces [Hash, nil] optional namespace mappings
    #   (defaults to the namespaces declared in the document)
    # @return [Nokogiri::XML::NodeSet] the matching nodes
    # @example Without custom namespaces
    #   response.xpath('//User')
    # @example With custom namespaces
    #   response.xpath('//ns:User', 'ns' => 'http://example.com/users')
    def xpath(path, namespaces = nil)
      doc.xpath(path, namespaces || xml_namespaces)
    end

    # Returns all XML namespaces declared in the response document.
    #
    # This is useful for building XPath queries that need to
    # reference namespaced elements.
    #
    # @return [Hash<String, String>] namespace prefix to URI mappings
    # @example
    #   response.xml_namespaces
    #   # => { "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
    #   #      "xmlns:ns1" => "http://example.com/users" }
    def xml_namespaces
      @xml_namespaces ||= doc.collect_namespaces
    end

    # ============================================================
    # Signature Verification Methods
    # ============================================================

    # Returns whether the response contains a signature.
    #
    # @return [Boolean] true if a ds:Signature element is present
    #
    # @example
    #   if response.signature_present?
    #     puts "Response is signed"
    #   end
    def signature_present?
      verifier.signature_present?
    end

    # Returns whether the response signature is valid.
    #
    # This performs full signature verification including:
    # - Locating the signing certificate (from BinarySecurityToken or provided)
    # - Verifying all Reference digests match the signed elements
    # - Verifying the SignatureValue over the canonicalized SignedInfo
    #
    # Returns false if no signature is present. Use {#signature_present?}
    # to distinguish between "no signature" and "invalid signature".
    #
    # @return [Boolean] true if signature is present and valid
    #
    # @example
    #   if response.signature_valid?
    #     # Safe to trust the response content
    #   else
    #     puts "Errors: #{response.signature_errors}"
    #   end
    def signature_valid?
      verifier.valid?
    end

    # Verifies the signature and raises an error if invalid.
    #
    # Use this method when you want to ensure the response is properly
    # signed and fail loudly if it's not.
    #
    # @raise [SignatureVerificationError] if signature is missing or invalid
    # @return [true] if signature is valid
    #
    # @example
    #   begin
    #     response.verify_signature!
    #     # Process trusted response
    #   rescue WSDL::SignatureVerificationError => e
    #     puts "Untrusted response: #{e.message}"
    #   end
    def verify_signature!
      raise SignatureVerificationError, 'Response does not contain a signature' unless signature_present?

      unless signature_valid?
        errors = signature_errors.join('; ')
        raise SignatureVerificationError, "Signature verification failed: #{errors}"
      end

      true
    end

    # Returns the IDs of all signed elements.
    #
    # These are the URI references from the signature's Reference elements,
    # typically including Body, Timestamp, and possibly WS-Addressing headers.
    #
    # @return [Array<String>] element IDs (e.g., ['Body-abc123', 'Timestamp-xyz789'])
    #
    # @example
    #   response.signed_element_ids
    #   # => ["Body-abc123", "Timestamp-xyz789"]
    def signed_element_ids
      verifier.signed_element_ids
    end

    # Returns the names of all signed elements.
    #
    # @return [Array<String>] element names (e.g., ['Body', 'Timestamp'])
    #
    # @example
    #   response.signed_elements
    #   # => ["Body", "Timestamp"]
    def signed_elements
      verifier.signed_elements
    end

    # Returns any errors from signature verification.
    #
    # This is populated after calling {#signature_valid?} and contains
    # details about why verification failed.
    #
    # @return [Array<String>] error messages
    #
    # @example
    #   unless response.signature_valid?
    #     response.signature_errors.each do |error|
    #       puts "Verification error: #{error}"
    #     end
    #   end
    def signature_errors
      verifier.errors
    end

    # Returns the signature algorithm used.
    #
    # @return [String, nil] the algorithm URI (e.g., 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
    def signature_algorithm
      verifier.signature_algorithm
    end

    # Returns the digest algorithm used.
    #
    # @return [String, nil] the algorithm URI from the first reference
    def digest_algorithm
      verifier.digest_algorithm
    end

    # Returns the certificate used to sign the response.
    #
    # This is either the certificate extracted from the BinarySecurityToken
    # in the response, or the certificate provided at initialization.
    #
    # @return [OpenSSL::X509::Certificate, nil] the signing certificate
    def signing_certificate
      # Trigger verification to extract certificate
      verifier.valid? unless verifier.certificate
      verifier.certificate
    end

    private

    # Returns the signature verifier instance.
    #
    # @return [Security::Verifier]
    #
    def verifier
      @verifier ||= Security::Verifier.new(@raw_response, certificate: @verify_certificate)
    end
  end

  # Error raised when signature verification fails.
  #
  # @example
  #   begin
  #     response.verify_signature!
  #   rescue WSDL::SignatureVerificationError => e
  #     log_security_event("Signature verification failed: #{e.message}")
  #   end
  class SignatureVerificationError < StandardError; end
end
