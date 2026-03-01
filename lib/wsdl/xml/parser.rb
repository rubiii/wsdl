# frozen_string_literal: true

require 'nokogiri'
require 'logging'
require_relative '../errors'

module WSDL
  module XML
    # Secure XML parsing with protection against common XML attacks.
    #
    # This module provides a centralized, secure way to parse XML throughout
    # the WSDL library. It protects against:
    #
    # - **XXE (XML External Entity) attacks:** External entities are not loaded
    #   because we omit the NOENT flag (which would enable substitution) and
    #   include NONET (which blocks network access).
    #
    # - **SSRF (Server-Side Request Forgery):** Network access during parsing
    #   is disabled via NONET, preventing the parser from making outbound requests.
    #
    # - **DTD-based attacks:** We deliberately omit DTDLOAD and DTDATTR flags,
    #   so external DTDs are not loaded and DTD attributes are not defaulted.
    #
    # - **Billion Laughs / XML Bomb:** Internal entity expansion is limited by
    #   Nokogiri/libxml2's default entity expansion limits. For defense in depth,
    #   use {.detect_threats} to identify suspicious patterns before parsing.
    #
    # ## Security Design
    #
    # Nokogiri's ParseOptions flags are *additive* — they enable features when present.
    # For security, we carefully choose which flags to include:
    #
    # **Flags we INCLUDE (enabled):**
    # - NONET: Disable network access (prevents SSRF, external entity fetching)
    # - NOCDATA: Merge CDATA as text (simplifies processing)
    # - STRICT: Require well-formed XML (for parse(), not parse_relaxed())
    # - NOBLANKS: Remove blank nodes (optional, for canonicalization)
    #
    # **Flags we deliberately OMIT (disabled):**
    # - NOENT: Would enable entity substitution — we leave it OFF
    # - DTDLOAD: Would load external DTDs — we leave it OFF
    # - DTDATTR: Would default attributes from DTD — we leave it OFF
    # - DTDVALID: Would validate against DTD — we leave it OFF
    #
    # @example Parse untrusted XML securely
    #   doc = WSDL::XML::Parser.parse(untrusted_xml)
    #
    # @example Parse with blank node removal (for canonicalization)
    #   doc = WSDL::XML::Parser.parse(xml, noblanks: true)
    #
    # @example Parse with threat logging
    #   doc = WSDL::XML::Parser.parse_with_logging(xml, logger)
    #
    # @see https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html
    # @see https://nokogiri.org/rdoc/Nokogiri/XML/ParseOptions.html
    #
    module Parser
      # Secure parse options for strict XML parsing.
      #
      # These options provide secure defaults:
      # - STRICT: Require well-formed XML
      # - NONET: Block all network access during parsing
      # - NOCDATA: Merge CDATA sections as text nodes
      #
      # Notably ABSENT (for security):
      # - NOENT: Not included, so entities are NOT substituted
      # - DTDLOAD: Not included, so external DTDs are NOT loaded
      # - DTDATTR: Not included, so DTD attributes are NOT defaulted
      #
      # @api private
      SECURE_PARSE_OPTIONS = Nokogiri::XML::ParseOptions::STRICT |
                             Nokogiri::XML::ParseOptions::NONET |
                             Nokogiri::XML::ParseOptions::NOCDATA

      # Secure parse options with blank node removal.
      #
      # Used for signature operations where whitespace must be normalized
      # for consistent canonicalization.
      #
      # @api private
      SECURE_PARSE_OPTIONS_NOBLANKS = SECURE_PARSE_OPTIONS |
                                      Nokogiri::XML::ParseOptions::NOBLANKS

      # Relaxed parse options that tolerate malformed XML.
      #
      # Used for third-party WSDL documents that may not be strictly valid.
      # Still includes security protections (NONET).
      #
      # @api private
      RELAXED_PARSE_OPTIONS = Nokogiri::XML::ParseOptions::NONET |
                              Nokogiri::XML::ParseOptions::RECOVER |
                              Nokogiri::XML::ParseOptions::NOCDATA

      # Relaxed parse options with blank node removal.
      # @api private
      RELAXED_PARSE_OPTIONS_NOBLANKS = RELAXED_PARSE_OPTIONS |
                                       Nokogiri::XML::ParseOptions::NOBLANKS

      class << self
        # Parses an XML string or returns an existing document.
        #
        # This method applies secure parsing options to protect against
        # XXE, SSRF, and other XML-based attacks. It requires well-formed XML.
        #
        # @param xml [String, Nokogiri::XML::Document] the XML to parse
        # @param noblanks [Boolean] remove blank nodes (default: false)
        #   Set to true when parsing for signature operations to ensure
        #   consistent canonicalization.
        #
        # @return [Nokogiri::XML::Document] the parsed document
        #
        # @raise [ArgumentError] if xml is not a String or Document
        # @raise [Nokogiri::XML::SyntaxError] if XML is malformed (strict mode)
        #
        # @example Basic usage
        #   doc = Parser.parse('<root><child>text</child></root>')
        #
        # @example With blank removal for signatures
        #   doc = Parser.parse(xml, noblanks: true)
        #
        def parse(xml, noblanks: false)
          case xml
          when Nokogiri::XML::Document
            xml
          when String
            options = noblanks ? SECURE_PARSE_OPTIONS_NOBLANKS : SECURE_PARSE_OPTIONS
            Nokogiri::XML(xml, nil, nil, options)
          else
            raise ArgumentError, "Expected String or Nokogiri::XML::Document, got #{xml.class}"
          end
        rescue Nokogiri::XML::SyntaxError => e
          raise_if_security_error(e)
        end

        # Parses XML with relaxed error handling.
        #
        # This is useful for parsing potentially malformed WSDL documents
        # from third parties that may not be strictly valid XML but are
        # still processable.
        #
        # **Security Note:** This still applies XXE and SSRF protections
        # (NONET is enabled, NOENT/DTDLOAD are not). It only relaxes the
        # strict well-formedness requirements via RECOVER.
        #
        # @param xml [String] the XML string to parse
        # @param noblanks [Boolean] remove blank nodes
        # @return [Nokogiri::XML::Document] the parsed document
        #
        def parse_relaxed(xml, noblanks: false)
          options = noblanks ? RELAXED_PARSE_OPTIONS_NOBLANKS : RELAXED_PARSE_OPTIONS
          Nokogiri::XML(xml, nil, nil, options)
        rescue Nokogiri::XML::SyntaxError => e
          raise_if_security_error(e)
        end

        # Parses XML with threat detection and logging.
        #
        # Scans the XML for suspicious patterns before parsing and logs
        # any detected threats. Useful for monitoring attack attempts
        # against your SOAP endpoints.
        #
        # @param xml [String] the XML string to parse
        # @param logger [Logger, Logging::Logger, nil] logger for threat warnings
        # @param noblanks [Boolean] remove blank nodes
        # @param strict [Boolean] use strict parsing (default: true)
        #
        # @return [Nokogiri::XML::Document] the parsed document
        #
        # @example With logging
        #   logger = Logging.logger['WSDL::Security']
        #   doc = Parser.parse_with_logging(response_xml, logger)
        #
        def parse_with_logging(xml, logger = nil, noblanks: false, strict: true)
          logger ||= Logging.logger[self]

          if xml.is_a?(String)
            threats = detect_threats(xml)
            logger.warn("Potential XML attack detected: #{threats.join(', ')}") if threats.any?
          end

          strict ? parse(xml, noblanks:) : parse_relaxed(xml, noblanks:)
        end

        # Checks if an XML document contains potentially dangerous constructs.
        #
        # This provides defense-in-depth by detecting attack patterns before
        # parsing. Even though our parser options block most attacks, this
        # helps identify and log malicious input.
        #
        # Detected threats:
        # - `:doctype` — DOCTYPE declaration (often used in XXE)
        # - `:entity_declaration` — ENTITY definitions
        # - `:external_reference` — SYSTEM or PUBLIC identifiers
        # - `:parameter_entity` — Parameter entity references (%entity;)
        # - `:deep_nesting` — Excessive tag nesting (potential DoS)
        # - `:large_attribute` — Very long attribute values (potential DoS)
        #
        # @param xml_string [String] the XML string to check
        # @return [Array<Symbol>] list of detected threat indicators
        #
        # @example Check for threats
        #   threats = Parser.detect_threats(xml)
        #   if threats.any?
        #     logger.warn("Suspicious XML: #{threats.join(', ')}")
        #   end
        #
        # @example Reject dangerous XML
        #   threats = Parser.detect_threats(xml)
        #   raise SecurityError, "Rejected: #{threats}" if threats.include?(:external_reference)
        #
        # rubocop:disable Metrics/CyclomaticComplexity
        def detect_threats(xml_string)
          threats = []

          # DOCTYPE declarations often indicate XXE attempts
          threats << :doctype if xml_string.match?(/<!DOCTYPE/i)

          # ENTITY declarations are used to define XXE payloads
          threats << :entity_declaration if xml_string.match?(/<!ENTITY/i)

          # SYSTEM keyword indicates external resource access
          threats << :external_reference if xml_string.match?(/\bSYSTEM\s+["']/i)

          # PUBLIC keyword also indicates external resource access
          threats << :external_reference if xml_string.match?(/\bPUBLIC\s+["']/i)

          # Parameter entities (%name;) are often used in advanced XXE
          threats << :parameter_entity if xml_string.match?(/%[a-zA-Z_][a-zA-Z0-9_]*;/)

          # Excessive nesting could indicate a DoS attempt
          open_tags = xml_string.scan(%r{<[a-zA-Z][^>/]*>}).length
          threats << :deep_nesting if open_tags > 10_000

          # Very long attribute values could indicate a DoS attempt
          threats << :large_attribute if xml_string.match?(/\w+\s*=\s*["'][^"']{100_000,}["']/)

          threats.uniq
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        # Parses XML with threat callback.
        #
        # This method scans for potential threats before parsing and invokes
        # the callback if any are found. The callback can log, raise, or
        # take other action.
        #
        # @param xml [String] the XML string to parse
        # @param noblanks [Boolean] remove blank nodes
        # @param strict [Boolean] use strict parsing (default: true)
        # @yield [threats] called when threats are detected
        # @yieldparam threats [Array<Symbol>] the detected threat types
        #
        # @return [Nokogiri::XML::Document] the parsed document
        #
        # @example Log threats but continue parsing
        #   Parser.parse_untrusted(xml) do |threats|
        #     logger.warn("XML threats detected: #{threats}")
        #   end
        #
        # @example Reject XML with external references
        #   Parser.parse_untrusted(xml) do |threats|
        #     if threats.include?(:external_reference)
        #       raise SecurityError, "External references not allowed"
        #     end
        #   end
        #
        def parse_untrusted(xml, noblanks: false, strict: true)
          if xml.is_a?(String)
            threats = detect_threats(xml)
            yield threats if threats.any? && block_given?
          end

          strict ? parse(xml, noblanks:) : parse_relaxed(xml, noblanks:)
        end

        private

        # Patterns in libxml2 error messages that indicate security-related failures.
        # These are checked case-insensitively.
        SECURITY_ERROR_PATTERNS = [
          /amplification/i,           # Entity amplification limit exceeded
          /entity.*loop/i,            # Entity reference loop detected
          /excessive\s+depth/i,       # Document depth limit exceeded
          /huge\s+input/i,            # HUGE flag required (size limit)
          /parser.*big/i,             # Parser size limits
          /maximum.*depth/i,          # Maximum depth exceeded
          /buffer.*limit/i,           # Buffer size limit exceeded
          /resource.*limit/i          # Resource limit exceeded
        ].freeze
        private_constant :SECURITY_ERROR_PATTERNS

        # Checks if a Nokogiri error is security-related and re-raises as XMLSecurityError.
        #
        # @param error [Nokogiri::XML::SyntaxError] the original error
        # @raise [WSDL::XMLSecurityError] if the error is security-related
        # @raise [Nokogiri::XML::SyntaxError] if the error is not security-related
        def raise_if_security_error(error)
          raise WSDL::XMLSecurityError, "XML security violation detected: #{error.message}" if security_error?(error)

          raise error
        end

        # Determines if a Nokogiri error indicates a security violation.
        #
        # @param error [Nokogiri::XML::SyntaxError] the error to check
        # @return [Boolean] true if the error is security-related
        def security_error?(error)
          message = error.message.to_s
          SECURITY_ERROR_PATTERNS.any? { |pattern| message.match?(pattern) }
        end
      end
    end
  end
end
