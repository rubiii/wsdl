# frozen_string_literal: true

module WSDL
  # WSDL and XSD document parsing.
  #
  # This module contains classes responsible for importing, resolving, and
  # parsing WSDL documents and their referenced XML schemas. It handles
  # recursive imports, relative path resolution, and builds an in-memory
  # representation of the WSDL structure.
  #
  # The main entry point is {Result}, which is created by {WSDL::Client}
  # when loading a WSDL document.
  #
  # @api private
  #
  module Parser
    require 'wsdl/parser/binding'
    require 'wsdl/parser/binding_operation'
    require 'wsdl/parser/input_output'
    require 'wsdl/parser/message_info'
    require 'wsdl/parser/operation_info'
    require 'wsdl/parser/port'
    require 'wsdl/parser/port_type'
    require 'wsdl/parser/port_type_operation'
    require 'wsdl/parser/service'
    require 'wsdl/parser/document'
    require 'wsdl/parser/document_collection'
    require 'wsdl/parser/resolver'
    require 'wsdl/parser/importer'
    require 'wsdl/parser/result'
    require 'wsdl/parser/cached_result'
  end
end
