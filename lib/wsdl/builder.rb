# frozen_string_literal: true

module WSDL
  # SOAP envelope and message building.
  #
  # This module contains classes responsible for constructing SOAP request
  # envelopes from Ruby data structures. It handles XML serialization,
  # namespace management, and both simple and complex type handling.
  #
  # The main classes are:
  # - {Envelope} - Builds complete SOAP envelopes with header and body
  # - {Message} - Serializes Ruby Hashes to XML message content
  # - {ExampleMessage} - Generates example message structures from WSDL definitions
  #
  # @api private
  #
  module Builder
    require 'wsdl/builder/envelope'
    require 'wsdl/builder/message'
    require 'wsdl/builder/example_message'
  end
end
