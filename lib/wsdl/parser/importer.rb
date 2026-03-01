# frozen_string_literal: true

require 'nokogiri'

module WSDL
  module Parser
    # Imports WSDL documents and their referenced schemas.
    #
    # Handles recursive imports, including WSDL imports and XSD imports/includes.
    # Supports relative paths resolved against the parent document's location.
    #
    # @api private
    #
    class Importer
      # Safety limit to prevent infinite loops with malformed WSDLs.
      MAX_SCHEMA_IMPORT_ITERATIONS = 100

      # Creates a new Importer instance.
      #
      # @param resolver [Resolver] the resolver for fetching documents
      # @param documents [DocumentCollection] the collection to store parsed documents
      # @param schemas [Schema::Collection] the collection to store parsed schemas
      def initialize(resolver, documents, schemas)
        @logger = Logging.logger[self]

        @resolver = resolver
        @documents = documents
        @schemas = schemas
      end

      # Imports a WSDL document and all its dependencies.
      #
      # @param location [String] the location of the WSDL (URL, file path, or XML string)
      # @return [void]
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
      #
      # @param location [String] the document location
      # @param base [String, nil] the base location for resolving relative paths
      # @yield [document, resolved_location] yields each parsed document
      # @yieldparam document [Document] the parsed document
      # @yieldparam resolved_location [String] the resolved absolute location
      # @return [void]
      def import_document(location, base:, &block)
        resolved_location = @resolver.resolve_location(location, base)

        if @import_locations.include? resolved_location
          @logger.info("Skipping already imported location #{resolved_location.inspect}.")
          return
        end

        xml = @resolver.resolve(location, base: base)
        @import_locations << resolved_location

        document = Document.new(Nokogiri.XML(xml), @schemas)
        block.call(document, resolved_location)

        # Resolve WSDL imports (relative to this document's location)
        document.imports.each do |import_location|
          @logger.info("Resolving WSDL import #{import_location.inspect}.")
          import_document(import_location, base: resolved_location, &block)
        end
      end

      # Iterates over all schema imports and includes, fetching and parsing them.
      #
      # @return [void]
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

      # Processes pending schema import and include references.
      #
      # @return [Boolean] true if any new schemas were processed
      def process_pending_schema_references
        found = false
        @schemas.each do |schema|
          found = true if process_references(schema.imports.values.compact, schema.source_location)
          found = true if process_references(schema.includes, schema.source_location, include_into: schema)
        end
        found
      end

      # Processes a list of schema references.
      #
      # @param locations [Array<String>] the locations to process
      # @param base [String, nil] the base location for resolving relative paths
      # @param include_into [Schema::Definition, nil] if provided, merge schemas into this definition
      # @return [Boolean] true if any references were processed
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

      # Processes a single schema reference.
      #
      # @param schema_location [String] the schema location
      # @param base [String, nil] the base location
      # @param include_into [Schema::Definition, nil] if provided, merge into this schema
      # @return [void]
      def process_schema_reference(schema_location, base, include_into: nil)
        resolved_location = @resolver.resolve_location(schema_location, base)
        @processed_locations.add(resolved_location)

        if @import_locations.include?(resolved_location)
          @logger.info("Skipping already imported schema #{schema_location.inspect}.")
          return
        end

        load_schema(schema_location, base, resolved_location, include_into)
      end

      # Loads and parses a schema from a location.
      #
      # @param schema_location [String] the schema location
      # @param base [String, nil] the base location
      # @param resolved_location [String] the resolved absolute location
      # @param include_into [Schema::Definition, nil] if provided, merge into this schema
      # @return [void]
      def load_schema(schema_location, base, resolved_location, include_into)
        action = include_into ? 'include' : 'import'
        @logger.info("Resolving XML Schema #{action} #{schema_location.inspect} (base: #{base.inspect}).")

        xml = @resolver.resolve(schema_location, base: base)
        @import_locations << resolved_location

        document = Document.new(Nokogiri.XML(xml), @schemas)
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

      # Applies loaded schemas to the collection or merges them into an existing schema.
      #
      # @param new_schemas [Array<Schema::Definition>] the newly loaded schemas
      # @param include_into [Schema::Definition, nil] if provided, merge into this schema
      # @return [void]
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
end
