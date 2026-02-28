# frozen_string_literal: true

require 'nokogiri'
require 'wsdl/definition/document'

class WSDL
  # Imports WSDL documents and their referenced schemas.
  # Handles recursive imports, including WSDL imports and XSD imports/includes.
  # Supports relative paths resolved against the parent document's location.
  #
  # @api private
  class Importer
    # Safety limit to prevent infinite loops with malformed WSDLs.
    MAX_SCHEMA_IMPORT_ITERATIONS = 100

    def initialize(resolver, documents, schemas)
      @logger = Logging.logger[self]

      @resolver = resolver
      @documents = documents
      @schemas = schemas
    end

    # Imports a WSDL document and all its dependencies.
    def import(location)
      @import_locations = []

      @logger.info("Resolving WSDL document #{location.inspect}.")
      import_document(location, base: nil) do |document, resolved_location|
        @documents << document
        @schemas.push(document.schemas(resolved_location))
      end

      # Resolve XML schema imports and includes
      import_schemas
    end

    private

    # Imports a single document, resolving relative paths against the base.
    def import_document(location, base:, &block)
      resolved_location = @resolver.resolve_location(location, base)

      if @import_locations.include? resolved_location
        @logger.info("Skipping already imported location #{resolved_location.inspect}.")
        return
      end

      xml = @resolver.resolve(location, base: base)
      @import_locations << resolved_location

      document = Definition::Document.new Nokogiri.XML(xml), @schemas
      block.call(document, resolved_location)

      # Resolve WSDL imports (relative to this document's location)
      document.imports.each do |import_location|
        @logger.info("Resolving WSDL import #{import_location.inspect}.")
        import_document(import_location, base: resolved_location, &block)
      end
    end

    # Iterates over all schema imports and includes, fetching and parsing them.
    def import_schemas
      # Keep processing until no new schemas are added
      # (schemas can import/include other schemas)
      @processed_locations = Set.new

      MAX_SCHEMA_IMPORT_ITERATIONS.times do |iteration|
        break unless process_pending_schema_references

        next unless iteration == MAX_SCHEMA_IMPORT_ITERATIONS - 1

        @logger.warn("Reached maximum schema import iterations (#{MAX_SCHEMA_IMPORT_ITERATIONS}). " \
                     'Some schemas may not have been imported.')
      end
    end

    # @return [Boolean] true if any new schemas were processed
    def process_pending_schema_references
      found = false
      @schemas.each do |schema|
        found = true if process_references(schema.imports.values.compact, schema.source_location)
        found = true if process_references(schema.includes, schema.source_location, include_into: schema)
      end
      found
    end

    def process_references(locations, base, include_into: nil)
      found = false
      locations.each do |location|
        resolved = @resolver.resolve_location(location, base)
        next if @processed_locations.include?(resolved)

        process_schema_reference(location, base, include_into: include_into)
        found = true
      end
      found
    end

    def process_schema_reference(schema_location, base, include_into: nil)
      resolved_location = @resolver.resolve_location(schema_location, base)
      @processed_locations.add(resolved_location)

      if @import_locations.include?(resolved_location)
        @logger.info("Skipping already imported schema #{schema_location.inspect}.")
        return
      end

      load_schema(schema_location, base, resolved_location, include_into)
    end

    def load_schema(schema_location, base, resolved_location, include_into)
      action = include_into ? 'include' : 'import'
      @logger.info("Resolving XML Schema #{action} #{schema_location.inspect} (base: #{base.inspect}).")

      xml = @resolver.resolve(schema_location, base: base)
      @import_locations << resolved_location

      document = Definition::Document.new Nokogiri.XML(xml), @schemas
      new_schemas = document.schemas(resolved_location)

      apply_schemas(new_schemas, include_into)
    rescue UnresolvableImportError
      # Re-raise errors about unresolvable relative paths - these are user errors
      # that need to be fixed, not transient failures
      raise
    rescue StandardError => e
      # Log and skip other errors (e.g., file not found, network errors)
      # as schemas may be optional or hosted on unreachable servers
      action = include_into ? 'include' : 'import'
      @logger.warn("Failed to resolve XML Schema #{action} #{schema_location.inspect}: #{e.message}")
    end

    def apply_schemas(new_schemas, include_into)
      if include_into
        # For includes, merge the schema contents into the including schema
        new_schemas.each { |s| include_into.merge(s) }
      else
        # For imports, add as separate schemas
        @schemas.push(new_schemas)
      end
    end
  end
end
