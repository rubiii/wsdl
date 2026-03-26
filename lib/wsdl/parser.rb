# frozen_string_literal: true

require 'wsdl/parser/message_reference'
require 'wsdl/parser/header_reference'
require 'wsdl/parser/binding'
require 'wsdl/parser/binding_operation'
require 'wsdl/parser/input_output'
require 'wsdl/parser/message_info'
require 'wsdl/parser/operation_info'
require 'wsdl/parser/operation_map'
require 'wsdl/parser/port'
require 'wsdl/parser/port_type'
require 'wsdl/parser/port_type_operation'
require 'wsdl/parser/service'
require 'wsdl/parser/document'
require 'wsdl/parser/document_collection'

module WSDL
  # WSDL and XSD document parsing.
  #
  # This module contains classes for parsing WSDL documents and their
  # referenced XML schemas into structured objects. I/O (fetching,
  # sandboxing, import orchestration) lives in {Resolver}.
  #
  # The main entry point is {.parse}, which coordinates the
  # {Resolver} and {Definition::Builder} to return a frozen {Definition}.
  #
  # @api private
  #
  module Parser
    # Parses a WSDL document and returns a frozen {Definition}.
    #
    # Validates the source, resolves all imports and schemas, and builds
    # the Definition IR in a single pass. This is the primary entry point
    # for the parse pipeline.
    #
    # @param wsdl [String] a URL or local file path to the WSDL document
    # @param http [Object] an HTTP client instance for fetching remote documents
    # @param parse_options [ParseOptions, nil] parse configuration.
    #   When omitted, {ParseOptions.default} is used.
    # @return [Definition] the frozen definition
    #
    # rubocop:disable Metrics/AbcSize -- straightforward factory: validate, import, build
    def self.parse(wsdl, http, parse_options = nil, **)
      parse_options ||= ParseOptions.default(**)

      documents = DocumentCollection.new
      schemas = Schema::Collection.new

      source = WSDL::Resolver::Source.validate_wsdl!(wsdl)
      resolved_sandbox_paths = source.resolve_sandbox_paths(parse_options.sandbox_paths)
      loader = WSDL::Resolver::Loader.new(http, sandbox_paths: resolved_sandbox_paths, limits: parse_options.limits)
      importer = WSDL::Resolver::Importer.new(loader, documents, schemas, parse_options)
      importer.import(source.value)

      Definition::Builder.new(
        documents:, schemas:,
        limits: parse_options.limits,
        schema_import_errors: importer.schema_import_errors.freeze,
        provenance: importer.provenance.freeze
      ).build
    end
    # rubocop:enable Metrics/AbcSize
  end
end
