# frozen_string_literal: true

require 'wsdl/parser/import_result'
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
  # The two entry points are:
  # - {.import} — resolves and imports WSDL documents and schemas
  # - {.parse} — imports and builds a frozen {Definition}
  #
  # @api private
  #
  module Parser
    # Resolves and imports a WSDL document and all its dependencies.
    #
    # Validates the source, resolves imports, and returns the parsed
    # documents and schemas without building a {Definition}. Use this
    # when you need access to the intermediate parse structures.
    #
    # @param wsdl [String] a URL or local file path to the WSDL document
    # @param http [Object] an HTTP client instance for fetching remote documents
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed
    # @param limits [Limits, nil] resource limits for DoS protection
    # @param strictness [Strictness, nil] strictness settings for schema validation
    # @return [ImportResult] the imported documents, schemas, and metadata
    def self.import(wsdl, http, sandbox_paths: nil, limits: nil, strictness: nil)
      parse_options = ParseOptions.default(sandbox_paths:, limits:, strictness:)

      documents = DocumentCollection.new
      schemas = Schema::Collection.new

      source = Resolver::Source.validate_wsdl!(wsdl)
      resolved_sandbox_paths = source.resolve_sandbox_paths(parse_options.sandbox_paths)
      loader = Resolver::Loader.new(http, sandbox_paths: resolved_sandbox_paths, limits: parse_options.limits)
      importer = Resolver::Importer.new(loader, documents, schemas, parse_options)
      importer.import(source.value)

      ImportResult.new(
        documents:, schemas:,
        provenance: importer.provenance.freeze,
        schema_import_errors: importer.schema_import_errors.freeze
      )
    end

    # Parses a WSDL document and returns a frozen {Definition}.
    #
    # Validates the source, resolves all imports and schemas, and builds
    # the Definition IR. This is the primary entry point for the parse
    # pipeline. The {QName} resolve cache is automatically cleared when
    # this method returns (even on exception) so that namespace hashes
    # and their referenced Nokogiri nodes can be garbage-collected.
    #
    # @param wsdl [String] a URL or local file path to the WSDL document
    # @param http [Object] an HTTP client instance for fetching remote documents
    # @param sandbox_paths [Array<String>, nil] directories where file access is allowed
    # @param limits [Limits, nil] resource limits for DoS protection
    # @param strictness [Strictness, nil] strictness settings for schema validation
    # @return [Definition] the frozen definition
    def self.parse(wsdl, http, sandbox_paths: nil, limits: nil, strictness: nil)
      result = import(wsdl, http, sandbox_paths:, limits:, strictness:)

      Definition::Builder.new(
        documents: result.documents, schemas: result.schemas,
        limits: limits || Limits.new,
        schema_import_errors: result.schema_import_errors,
        provenance: result.provenance
      ).build
    ensure
      QName.clear_resolve_cache
    end
  end
end
