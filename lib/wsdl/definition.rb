# frozen_string_literal: true

require 'wsdl/definition/element_hash'

module WSDL
  # Abstract representation of a parsed WSDL service.
  #
  # A Definition is a frozen, serializable snapshot of everything the library
  # knows about a WSDL service — its services, ports, operations, and message
  # structures. It serves as the intermediate representation (IR) that all
  # downstream consumers (Client, Operation, Response) operate on.
  #
  # @see WSDL.parse
  # @see WSDL.load
  #
  class Definition
    # @api private
    # @return [Hash{Symbol => Object}] internal data
    attr_reader :data
  end
end
