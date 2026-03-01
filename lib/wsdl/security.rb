# frozen_string_literal: true

module WSDL
  # WS-Security implementation for SOAP message security.
  #
  # This module provides support for the OASIS WS-Security specifications:
  # - SOAP Message Security 1.1
  # - UsernameToken Profile 1.1
  # - X.509 Token Profile 1.1
  #
  # It enables authentication through username/password tokens and
  # message integrity through X.509 certificate signatures.
  #
  # @example UsernameToken authentication
  #   operation = wsdl.operation('Service', 'Port', 'Operation')
  #   operation.security.username_token('user', 'secret')
  #   response = operation.call
  #
  # @example Digest authentication
  #   operation.security.username_token('user', 'secret', digest: true)
  #
  # @example X.509 certificate signing
  #   cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
  #   key = OpenSSL::PKey::RSA.new(File.read('key.pem'), 'password')
  #
  #   operation.security.timestamp
  #   operation.security.signature(certificate: cert, private_key: key)
  #   response = operation.call
  #
  # @example Combined authentication and signing
  #   operation.security.username_token('user', 'secret')
  #   operation.security.timestamp(expires_in: 300)
  #   operation.security.signature(
  #     certificate: cert,
  #     private_key: key,
  #     digest_algorithm: :sha256
  #   )
  #
  # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-SOAPMessageSecurity.pdf
  # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-UsernameTokenProfile.pdf
  # @see https://docs.oasis-open.org/wss/v1.1/wss-v1.1-spec-os-x509TokenProfile.pdf
  #
  module Security
    # Load constants first as other classes depend on them
    require 'wsdl/security/constants'

    # Load utility modules
    require 'wsdl/security/id_generator'
    require 'wsdl/security/algorithm_mapper'
    require 'wsdl/security/reference'
    require 'wsdl/security/signature_options'
    require 'wsdl/security/xml_builder_helper'

    # Load individual security components
    require 'wsdl/security/timestamp'
    require 'wsdl/security/username_token'
    require 'wsdl/security/canonicalizer'
    require 'wsdl/security/digester'
    require 'wsdl/security/signature'
    require 'wsdl/security/verifier'

    # Load configuration and header builder
    require 'wsdl/security/config'
    require 'wsdl/security/response_verification'
    require 'wsdl/security/security_header'
  end
end
