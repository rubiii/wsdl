# frozen_string_literal: true

require 'timeout'
require 'uri'
require 'wsdl/xml/parser'

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
      include Log

      # Exceptions that are treated as recoverable schema import failures.
      #
      # These are wrapped into {SchemaImportError} and either raised or collected
      # depending on strict schema mode.
      #
      # @return [Array<Class>]
      RECOVERABLE_SCHEMA_IMPORT_ERRORS = [
        SystemCallError,
        IOError,
        EOFError,
        SocketError,
        URI::InvalidURIError,
        Timeout::Error
      ].tap { |errors|
        errors << OpenSSL::SSL::SSLError if defined?(OpenSSL::SSL::SSLError)
        errors << HTTPClient::BadResponseError if defined?(HTTPClient::BadResponseError)
        errors << HTTPClient::TimeoutError if defined?(HTTPClient::TimeoutError)
      }.freeze

      # Creates a new Importer instance.
      #
      # @param resolver [Resolver] the resolver for fetching documents
      # @param documents [DocumentCollection] the collection to store parsed documents
      # @param schemas [Schema::Collection] the collection to store parsed schemas
      # @param parse_options [ParseOptions] parse configuration options
      #
      def initialize(resolver, documents, schemas, parse_options)
        @resolver = resolver
        @documents = documents
        @schemas = schemas
        @limits = parse_options.limits
        @reject_doctype = parse_options.reject_doctype
        @strict_schema = parse_options.strict_schema
        @schema_count = 0
        @schema_import_errors = []
      end

      # Recoverable schema import errors captured during import.
      #
      # @return [Array<SchemaImportError>]
      attr_reader :schema_import_errors

      # Imports a WSDL document and all its dependencies.
      #
      # @param location [String] the location of the WSDL (URL or file path)
      # @return [void]
      def import(location)
        @import_locations = []

        logger.info("Resolving WSDL document #{location.inspect}.")
        import_document(location, base: nil) do |document, resolved_location|
          @documents << document
          schemas = document.schemas(resolved_location)
          track_schema_count(schemas.size)
          @schemas.push(schemas)
        end

        # Resolve XML schema imports and includes
        import_schemas

        @documents.seal!
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
          logger.info("Skipping already imported location #{resolved_location.inspect}.")
          return
        end

        xml = @resolver.resolve(location, base: base)
        @import_locations << resolved_location

        parsed = XML::Parser.parse_with_logging(xml, strict: false, reject_doctype: @reject_doctype)
        document = Document.new(parsed, @schemas)
        block.call(document, resolved_location)

        # Resolve WSDL imports (relative to this document's location)
        document.imports.each do |import_location|
          logger.info("Resolving WSDL import #{import_location.inspect}.")
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

        max_iterations = @limits.max_schema_import_iterations
        return import_schemas_unlimited unless max_iterations

        max_iterations.times do |iteration|
          break unless process_pending_schema_references

          next unless iteration == max_iterations - 1

          logger.warn("Reached maximum schema import iterations (#{max_iterations}). " \
                      'Some schemas may not have been imported.')
        end
      end

      # Processes schema references without an iteration cap.
      #
      # @return [void]
      def import_schemas_unlimited
        loop { break unless process_pending_schema_references }
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
          logger.info("Skipping already imported schema #{schema_location.inspect}.")
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
        logger.info("Resolving XML Schema #{action} #{schema_location.inspect} (base: #{base.inspect}).")

        xml = load_schema_xml(schema_location, base, action)
        @import_locations << resolved_location

        parsed = parse_schema_xml(xml, schema_location, base, action)
        document = Document.new(parsed, @schemas)
        new_schemas = document.schemas(resolved_location)

        apply_schemas(new_schemas, include_into)
      rescue SchemaImportError => e
        handle_schema_import_error(e)
      end

      # Resolves schema XML and wraps recoverable fetch failures.
      #
      # @param schema_location [String] schema import/include location
      # @param base [String, nil] parent document location
      # @param action [String] import action (`import` or `include`)
      # @return [String] raw schema XML
      # @raise [SchemaImportError] when schema cannot be resolved
      def load_schema_xml(schema_location, base, action)
        @resolver.resolve(schema_location, base: base)
      rescue *RECOVERABLE_SCHEMA_IMPORT_ERRORS => e
        raise SchemaImportError.new(
          "Failed to resolve XML Schema #{action} #{schema_location.inspect} " \
          "(base: #{base.inspect}): #{e.class}: #{e.message}",
          location: schema_location,
          base_location: base,
          action:
        ), cause: e
      end

      # Parses schema XML and wraps malformed XML parse failures.
      #
      # @param xml [String] schema XML content
      # @param schema_location [String] schema import/include location
      # @param base [String, nil] parent document location
      # @param action [String] import action (`import` or `include`)
      # @return [Nokogiri::XML::Document] parsed XML document
      # @raise [SchemaImportParseError] when XML is malformed
      def parse_schema_xml(xml, schema_location, base, action)
        XML::Parser.parse_with_logging(xml, strict: false, reject_doctype: @reject_doctype)
      rescue Nokogiri::XML::SyntaxError => e
        raise SchemaImportParseError.new(
          "Failed to parse XML Schema #{action} #{schema_location.inspect} " \
          "(base: #{base.inspect}): #{e.class}: #{e.message}",
          location: schema_location,
          base_location: base,
          action:
        ), cause: e
      end

      # Handles recoverable schema import failures according to policy.
      #
      # @param error [SchemaImportError] the recoverable import failure
      # @return [void]
      # @raise [SchemaImportError] when strict schema mode is enabled
      def handle_schema_import_error(error)
        @schema_import_errors << error
        raise error if @strict_schema

        logger.warn(error.message)
      end

      # Applies loaded schemas to the collection or merges them into an existing schema.
      #
      # @param new_schemas [Array<Schema::Definition>] the newly loaded schemas
      # @param include_into [Schema::Definition, nil] if provided, merge into this schema
      # @return [void]
      def apply_schemas(new_schemas, include_into)
        # Count all schemas toward the limit (includes add complexity too)
        track_schema_count(new_schemas.size)

        if include_into
          # For includes, merge the schema contents into the including schema
          new_schemas.each { |s| include_into.merge(s) }
        else
          # For imports, add as separate schemas
          @schemas.push(new_schemas)
        end
      end

      # Tracks schema count and validates against limit.
      #
      # @param count [Integer] the number of schemas to add
      # @raise [ResourceLimitError] if total exceeds max_schemas
      def track_schema_count(count)
        @schema_count += count

        return unless @limits.max_schemas
        return if @schema_count <= @limits.max_schemas

        raise ResourceLimitError.new(
          "Schema count #{@schema_count} exceeds limit of #{@limits.max_schemas}. " \
          'Consider increasing limits or reviewing the WSDL for excessive imports.',
          limit_name: :max_schemas,
          limit_value: @limits.max_schemas,
          actual_value: @schema_count
        )
      end
    end
  end
end
