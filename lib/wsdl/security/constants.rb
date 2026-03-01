# frozen_string_literal: true

module WSDL
  module Security
    # WS-Security constants including namespaces and URIs from OASIS specifications.
    #
    # Constants are organized into nested modules for discoverability:
    # - {NS} — XML namespace URIs
    # - {Algorithms} — Cryptographic algorithm URIs
    # - {TokenProfiles} — WS-Security token profile URIs
    # - {Encoding} — Encoding type URIs
    # - {KeyReference} — Certificate reference methods
    #
    # @example Accessing namespace constants
    #   WSDL::Security::Constants::NS::Security::WSSE
    #   # => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    #
    # @example Accessing algorithm constants
    #   WSDL::Security::Constants::Algorithms::Digest::SHA256
    #   # => "http://www.w3.org/2001/04/xmlenc#sha256"
    #
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-SOAPMessageSecurity.pdf
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf
    #
    module Constants
      # XML namespace URIs organized by specification.
      module NS
        # WS-Security namespaces (OASIS).
        # @see https://docs.oasis-open.org/wss/v1.1/
        module Security
          # WS-Security Extension namespace (wsse)
          WSSE = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'

          # WS-Security Utility namespace (wsu)
          WSU = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'
        end

        # XML Digital Signature namespaces (W3C).
        # @see https://www.w3.org/TR/xmldsig-core1/
        module Signature
          # XML Digital Signature namespace (ds)
          DS = 'http://www.w3.org/2000/09/xmldsig#'

          # Exclusive XML Canonicalization namespace (ec)
          EC = 'http://www.w3.org/2001/10/xml-exc-c14n#'
        end

        # WS-Addressing namespaces (W3C).
        # @see https://www.w3.org/TR/ws-addr-core/
        module Addressing
          # WS-Addressing 1.0 namespace (2005)
          V1_0 = 'http://www.w3.org/2005/08/addressing'

          # WS-Addressing 2004/08 namespace (legacy)
          V2004 = 'http://schemas.xmlsoap.org/ws/2004/08/addressing'
        end

        # SOAP envelope namespaces.
        module SOAP
          # SOAP 1.1 namespace
          V1_1 = 'http://schemas.xmlsoap.org/soap/envelope/'

          # SOAP 1.2 namespace
          V1_2 = 'http://www.w3.org/2003/05/soap-envelope'
        end
      end

      # Cryptographic algorithm URIs for XML Digital Signatures.
      #
      # @see https://www.w3.org/TR/xmldsig-core1/
      # @see https://www.w3.org/TR/xmlenc-core1/
      module Algorithms
        # Digest algorithm URIs.
        module Digest
          # SHA-1 digest algorithm (legacy, discouraged for new signatures)
          SHA1 = 'http://www.w3.org/2000/09/xmldsig#sha1'

          # SHA-224 digest algorithm
          SHA224 = 'http://www.w3.org/2001/04/xmldsig-more#sha224'

          # SHA-256 digest algorithm (recommended)
          SHA256 = 'http://www.w3.org/2001/04/xmlenc#sha256'

          # SHA-384 digest algorithm
          SHA384 = 'http://www.w3.org/2001/04/xmldsig-more#sha384'

          # SHA-512 digest algorithm
          SHA512 = 'http://www.w3.org/2001/04/xmlenc#sha512'
        end

        # Signature algorithm URIs.
        module Signature
          # RSA with SHA-1 (legacy, verification only)
          RSA_SHA1 = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'

          # RSA with SHA-224
          RSA_SHA224 = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha224'

          # RSA with SHA-256 (recommended)
          RSA_SHA256 = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'

          # RSA with SHA-384
          RSA_SHA384 = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha384'

          # RSA with SHA-512
          RSA_SHA512 = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'

          # ECDSA with SHA-1 (legacy, discouraged)
          ECDSA_SHA1 = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha1'

          # ECDSA with SHA-224
          ECDSA_SHA224 = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha224'

          # ECDSA with SHA-256 (required by XML Signature 1.1)
          ECDSA_SHA256 = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha256'

          # ECDSA with SHA-384
          ECDSA_SHA384 = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha384'

          # ECDSA with SHA-512
          ECDSA_SHA512 = 'http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha512'

          # DSA with SHA-1 (legacy)
          DSA_SHA1 = 'http://www.w3.org/2000/09/xmldsig#dsa-sha1'

          # DSA with SHA-256
          DSA_SHA256 = 'http://www.w3.org/2009/xmldsig11#dsa-sha256'
        end

        # Canonicalization algorithm URIs.
        #
        # @see https://www.w3.org/TR/xml-exc-c14n/
        # @see https://www.w3.org/TR/xml-c14n/
        # @see https://www.w3.org/TR/xml-c14n11/
        module Canonicalization
          # Exclusive XML Canonicalization 1.0
          EXCLUSIVE_1_0 = 'http://www.w3.org/2001/10/xml-exc-c14n#'

          # Exclusive XML Canonicalization 1.0 with comments
          EXCLUSIVE_1_0_WITH_COMMENTS = 'http://www.w3.org/2001/10/xml-exc-c14n#WithComments'

          # Inclusive XML Canonicalization 1.0
          INCLUSIVE_1_0 = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'

          # Inclusive XML Canonicalization 1.0 with comments
          INCLUSIVE_1_0_WITH_COMMENTS = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315#WithComments'

          # Inclusive XML Canonicalization 1.1
          INCLUSIVE_1_1 = 'http://www.w3.org/2006/12/xml-c14n11'

          # Inclusive XML Canonicalization 1.1 with comments
          INCLUSIVE_1_1_WITH_COMMENTS = 'http://www.w3.org/2006/12/xml-c14n11#WithComments'
        end

        # Transform algorithm URIs.
        module Transform
          # Enveloped signature transform
          ENVELOPED_SIGNATURE = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature'
        end
      end

      # WS-Security token profile URIs.
      module TokenProfiles
        # Base URI for WS-Security token profiles
        BASE_URI = 'http://docs.oasis-open.org/wss/2004/01'

        # UsernameToken profile URIs.
        module UsernameToken
          # Password type: plain text
          PASSWORD_TEXT = "#{BASE_URI}/oasis-200401-wss-username-token-profile-1.0#PasswordText".freeze

          # Password type: digest (SHA-1)
          PASSWORD_DIGEST = "#{BASE_URI}/oasis-200401-wss-username-token-profile-1.0#PasswordDigest".freeze
        end

        # X.509 certificate token profile URIs.
        module X509
          # X.509 v3 certificate token type
          V3 = "#{BASE_URI}/oasis-200401-wss-x509-token-profile-1.0#X509v3".freeze

          # X.509 Subject Key Identifier reference type
          SKI = "#{BASE_URI}/oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier".freeze
        end
      end

      # Encoding type URIs.
      module Encoding
        # Base64 binary encoding
        BASE64 = "#{TokenProfiles::BASE_URI}/oasis-200401-wss-soap-message-security-1.0#Base64Binary".freeze
      end

      # Reference methods for identifying the signing certificate in KeyInfo.
      module KeyReference
        # Embed certificate as BinarySecurityToken and reference by ID (default).
        # The full certificate is included in the message.
        BINARY_SECURITY_TOKEN = :binary_security_token

        # Reference by X.509 Issuer Distinguished Name and Serial Number.
        # Recipient must already have the certificate.
        ISSUER_SERIAL = :issuer_serial

        # Reference by Subject Key Identifier (SKI) extension.
        # Recipient must already have the certificate; cert must have SKI extension.
        SUBJECT_KEY_IDENTIFIER = :subject_key_identifier
      end

      # Standard WS-Addressing header elements that may be signed.
      WS_ADDRESSING_HEADERS = %w[
        To
        From
        ReplyTo
        FaultTo
        Action
        MessageID
        RelatesTo
      ].freeze

      # Default namespace prefixes used when building XML.
      NAMESPACE_PREFIXES = {
        'wsse' => NS::Security::WSSE,
        'wsu' => NS::Security::WSU,
        'ds' => NS::Signature::DS,
        'ec' => NS::Signature::EC,
        'wsa' => NS::Addressing::V1_0
      }.freeze

      # Default explicit namespace prefixes for XML elements.
      # Used when explicit_namespace_prefixes option is enabled.
      EXPLICIT_PREFIXES = {
        wsse: 'wsse',
        wsu: 'wsu',
        ds: 'ds',
        ec: 'ec'
      }.freeze
    end
  end
end
