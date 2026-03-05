# frozen_string_literal: true

module WSDL
  # Namespace URI constants used throughout the WSDL library.
  #
  # This module centralizes all XML namespace URIs to avoid duplication
  # and provide a single source of truth for namespace references.
  #
  # @example Referencing a namespace
  #   WSDL::NS::XSD  # => "http://www.w3.org/2001/XMLSchema"
  #
  # @api private
  #
  module NS
    # XML Schema namespace URI.
    # Used for XSD type definitions (xs:string, xs:int, etc.)
    XSD = 'http://www.w3.org/2001/XMLSchema'

    # XML Schema Instance namespace URI.
    # Used for xsi:nil, xsi:type attributes.
    XSI = 'http://www.w3.org/2001/XMLSchema-instance'

    # WSDL 1.1 namespace URI.
    # Used for WSDL document elements (definitions, types, message, etc.)
    WSDL = 'http://schemas.xmlsoap.org/wsdl/'

    # WSDL SOAP 1.1 binding namespace URI.
    # Used for SOAP 1.1 binding elements in WSDL documents.
    WSDL_SOAP_1_1 = 'http://schemas.xmlsoap.org/wsdl/soap/'

    # WSDL SOAP 1.2 binding namespace URI.
    # Used for SOAP 1.2 binding elements in WSDL documents.
    WSDL_SOAP_1_2 = 'http://schemas.xmlsoap.org/wsdl/soap12/'

    # SOAP 1.1 envelope namespace URI.
    # Used for the SOAP Envelope, Header, and Body elements in SOAP 1.1 messages.
    SOAP_1_1 = 'http://schemas.xmlsoap.org/soap/envelope/'

    # SOAP 1.2 envelope namespace URI.
    # Used for the SOAP Envelope, Header, and Body elements in SOAP 1.2 messages.
    SOAP_1_2 = 'http://www.w3.org/2003/05/soap-envelope'

    # WSDL 2.0 namespace URI.
    # Used only for detection — WSDL 2.0 is not supported.
    WSDL_2_0 = 'http://www.w3.org/ns/wsdl'
  end
end
