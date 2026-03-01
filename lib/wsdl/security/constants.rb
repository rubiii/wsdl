# frozen_string_literal: true

module WSDL
  module Security
    # WS-Security constants including namespaces and URIs from OASIS specifications.
    #
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-SOAPMessageSecurity.pdf
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
    # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf
    #
    module Constants
      # WS-Security Extension namespace (wsse)
      NS_WSSE = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'

      # WS-Security Utility namespace (wsu)
      NS_WSU = 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'

      # XML Digital Signature namespace (ds)
      NS_DS = 'http://www.w3.org/2000/09/xmldsig#'

      # Exclusive XML Canonicalization namespace (ec)
      NS_EC = 'http://www.w3.org/2001/10/xml-exc-c14n#'

      # --- WS-Addressing Namespaces ---

      # WS-Addressing 1.0 namespace (wsa)
      NS_WSA = 'http://www.w3.org/2005/08/addressing'

      # WS-Addressing 2004/08 namespace (legacy)
      NS_WSA_2004 = 'http://schemas.xmlsoap.org/ws/2004/08/addressing'

      # --- SOAP Namespaces ---

      # SOAP 1.1 namespace
      NS_SOAP_1_1 = 'http://schemas.xmlsoap.org/soap/envelope/'

      # SOAP 1.2 namespace
      NS_SOAP_1_2 = 'http://www.w3.org/2003/05/soap-envelope'

      # Base URI for WS-Security token profiles
      BASE_WSS_URI = 'http://docs.oasis-open.org/wss/2004/01'

      # --- UsernameToken Profile URIs ---

      # Password type: plain text
      PASSWORD_TEXT_URI = "#{BASE_WSS_URI}/oasis-200401-wss-username-token-profile-1.0#PasswordText".freeze

      # Password type: digest (SHA-1)
      PASSWORD_DIGEST_URI = "#{BASE_WSS_URI}/oasis-200401-wss-username-token-profile-1.0#PasswordDigest".freeze

      # --- X.509 Token Profile URIs ---

      # X.509 v3 certificate token type
      X509_V3_URI = "#{BASE_WSS_URI}/oasis-200401-wss-x509-token-profile-1.0#X509v3".freeze

      # X.509 Subject Key Identifier reference type
      X509_SKI_URI = "#{BASE_WSS_URI}/oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier".freeze

      # --- Encoding Types ---

      # Base64 binary encoding
      BASE64_ENCODING_URI = "#{BASE_WSS_URI}/oasis-200401-wss-soap-message-security-1.0#Base64Binary".freeze

      # --- Canonicalization Algorithms ---

      # Exclusive XML Canonicalization 1.0
      EXC_C14N_URI = 'http://www.w3.org/2001/10/xml-exc-c14n#'

      # Inclusive XML Canonicalization 1.0
      C14N_URI = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315'

      # Inclusive XML Canonicalization 1.1
      C14N_11_URI = 'http://www.w3.org/2006/12/xml-c14n11'

      # --- Digest Algorithms ---

      # SHA-1 digest algorithm
      SHA1_URI = 'http://www.w3.org/2000/09/xmldsig#sha1'

      # SHA-256 digest algorithm
      SHA256_URI = 'http://www.w3.org/2001/04/xmlenc#sha256'

      # SHA-512 digest algorithm
      SHA512_URI = 'http://www.w3.org/2001/04/xmlenc#sha512'

      # --- Signature Algorithms ---

      # RSA with SHA-1 signature algorithm
      RSA_SHA1_URI = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'

      # RSA with SHA-256 signature algorithm
      RSA_SHA256_URI = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'

      # RSA with SHA-512 signature algorithm
      RSA_SHA512_URI = 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha512'

      # --- Transform Algorithms ---

      # Enveloped signature transform
      ENVELOPED_SIGNATURE_URI = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature'

      # --- Key Reference Methods ---

      # Reference methods for identifying the signing certificate in KeyInfo
      module KeyReference
        # Embed certificate as BinarySecurityToken and reference by ID (default)
        # The full certificate is included in the message
        BINARY_SECURITY_TOKEN = :binary_security_token

        # Reference by X.509 Issuer Distinguished Name and Serial Number
        # Recipient must already have the certificate
        ISSUER_SERIAL = :issuer_serial

        # Reference by Subject Key Identifier (SKI) extension
        # Recipient must already have the certificate; cert must have SKI extension
        SUBJECT_KEY_IDENTIFIER = :subject_key_identifier
      end

      # --- WS-Addressing Element Names ---

      # Standard WS-Addressing header elements that may be signed
      WS_ADDRESSING_HEADERS = %w[
        To
        From
        ReplyTo
        FaultTo
        Action
        MessageID
        RelatesTo
      ].freeze

      # --- Namespace Prefixes ---

      # Default namespace prefixes used when building XML
      NAMESPACES = {
        'wsse' => NS_WSSE,
        'wsu' => NS_WSU,
        'ds' => NS_DS,
        'ec' => NS_EC,
        'wsa' => NS_WSA
      }.freeze

      # Default explicit namespace prefixes for XML elements
      # Used when explicit_namespace_prefixes option is enabled
      DEFAULT_NS_PREFIXES = {
        wsse: 'wsse',
        wsu: 'wsu',
        ds: 'ds',
        ec: 'ec'
      }.freeze
    end
  end
end
