# frozen_string_literal: true

require 'openssl'
require 'base64'
require_relative 'base'

module WSDL
  module Security
    class Verifier
      # Resolves and normalizes X.509 certificates for signature verification.
      #
      # This class handles certificate extraction from SOAP messages and
      # normalization of certificate formats. It supports:
      #
      # - Extracting certificates from BinarySecurityToken elements
      # - Using externally provided certificates
      # - Normalizing PEM strings to OpenSSL::X509::Certificate objects
      #
      # @example Extracting certificate from document
      #   resolver = CertificateResolver.new(document, security_node)
      #   if resolver.resolve
      #     cert = resolver.certificate
      #   else
      #     puts resolver.errors
      #   end
      #
      # @example Using a provided certificate
      #   resolver = CertificateResolver.new(document, security_node, provided: pem_string)
      #   resolver.resolve
      #   cert = resolver.certificate
      #
      class CertificateResolver < Base
        # @return [OpenSSL::X509::Certificate, nil] the resolved certificate
        attr_reader :certificate

        # Creates a new certificate resolver.
        #
        # @param document [Nokogiri::XML::Document] the SOAP document
        # @param security_node [Nokogiri::XML::Element, nil] the wsse:Security element
        # @param provided [OpenSSL::X509::Certificate, String, nil] optional certificate
        #   to use instead of extracting from the document
        def initialize(document, security_node, provided: nil)
          super()
          @document = document
          @security_node = security_node
          @provided = provided
          @certificate = nil
        end

        # Resolves the certificate for verification.
        #
        # If a certificate was provided at initialization, it is normalized and used.
        # Otherwise, the certificate is extracted from the BinarySecurityToken in
        # the Security header.
        #
        # @return [Boolean] true if a certificate was successfully resolved
        def resolve
          @certificate = if @provided
            normalize_provided_certificate
          else
            extract_from_document
          end

          return true if @certificate

          add_failure('No certificate found for verification')
        end

        # Alias for consistency with other validators.
        #
        # @return [Boolean] true if certificate was resolved
        def valid?
          resolve
        end

        private

        # Normalizes a provided certificate to OpenSSL::X509::Certificate.
        #
        # @return [OpenSSL::X509::Certificate, nil] the normalized certificate
        def normalize_provided_certificate
          case @provided
          when OpenSSL::X509::Certificate
            @provided
          when String
            parse_certificate(@provided)
          else
            add_failure_nil("Invalid certificate type: #{@provided.class}")
          end
        end

        # Extracts the certificate from BinarySecurityToken in the document.
        #
        # @return [OpenSSL::X509::Certificate, nil] the extracted certificate
        def extract_from_document
          bst = find_binary_security_token
          return nil unless bst

          der_data = Base64.decode64(bst.text)
          parse_certificate(der_data)
        end

        # Finds the BinarySecurityToken element.
        #
        # @return [Nokogiri::XML::Element, nil] the BST element
        def find_binary_security_token
          return nil unless @security_node

          @security_node.at_xpath('wsse:BinarySecurityToken', ns)
        end

        # Parses certificate data into an OpenSSL::X509::Certificate.
        #
        # @param data [String] PEM or DER encoded certificate data
        # @return [OpenSSL::X509::Certificate, nil] the parsed certificate
        def parse_certificate(data)
          OpenSSL::X509::Certificate.new(data)
        rescue OpenSSL::X509::CertificateError => e
          add_failure_nil("Failed to parse certificate: #{e.message}")
        end
      end
    end
  end
end
