# frozen_string_literal: true

require 'nokogiri'
require 'wsdl/definition/document'

class WSDL
  # Imports WSDL documents and their referenced schemas.
  #
  # This class handles the recursive import of WSDL documents,
  # including any imported WSDLs and XML Schema imports referenced
  # within them. It tracks already-imported locations to prevent
  # duplicate imports and infinite loops.
  #
  # @api private
  #
  class Importer
    # Creates a new Importer instance.
    #
    # @param resolver [Resolver] the resolver for fetching document content
    # @param documents [Definition::DocumentCollection] the collection to store parsed WSDL documents
    # @param schemas [XS::SchemaCollection] the collection to store parsed XML schemas
    def initialize(resolver, documents, schemas)
      @logger = Logging.logger[self]

      @resolver = resolver
      @documents = documents
      @schemas = schemas
    end

    # Imports a WSDL document and all its dependencies.
    #
    # This method recursively imports the main WSDL document along with
    # any WSDL imports and XML Schema imports it references. Documents
    # are added to the collections provided during initialization.
    #
    # @param location [String] a URL, file path, or raw XML string of the WSDL document
    # @return [void]
    def import(location)
      @import_locations = []

      @logger.info("Resolving WSDL document #{location.inspect}.")
      import_document(location) do |document|
        @documents << document
        @schemas.push(document.schemas)
      end

      # resolve xml schema imports
      import_schemas do |schema_location|
        @logger.info("Resolving XML schema import #{schema_location.inspect}.")

        import_document(schema_location) do |document|
          @schemas.push(document.schemas)
        end
      end
    end

    private

    # Imports a single document from a location.
    #
    # Resolves the location, parses the XML, and yields the resulting
    # document. Also recursively imports any WSDL imports found within
    # the document.
    #
    # @param location [String] the document location
    # @yield [document] yields the parsed document
    # @yieldparam document [Definition::Document] the parsed document
    # @return [void]
    def import_document(location, &block)
      if @import_locations.include? location
        @logger.info("Skipping already imported location #{location.inspect}.")
        return
      end

      xml = @resolver.resolve(location)
      @import_locations << location

      document = Definition::Document.new Nokogiri.XML(xml), @schemas
      block.call(document)

      # resolve wsdl imports
      document.imports.each do |import_location|
        @logger.info("Resolving WSDL import #{import_location.inspect}.")
        import_document(import_location, &block)
      end
    end

    # Iterates over all schema imports and yields their locations.
    #
    # Only yields absolute URLs; relative schema locations are skipped
    # with a warning since they cannot be reliably resolved.
    #
    # @yield [schema_location] yields each schema location to import
    # @yieldparam schema_location [String] the schema URL to import
    # @return [void]
    def import_schemas
      @schemas.each do |schema|
        schema.imports.each_value do |schema_location|
          next unless schema_location

          unless absolute_url? schema_location
            @logger.warn("Skipping XML Schema import #{schema_location.inspect}.")
            next
          end

          # TODO: also skip if the schema was already imported

          yield(schema_location)
        end
      end
    end

    # Checks if a location is an absolute HTTP/HTTPS URL.
    #
    # @param location [String] the location to check
    # @return [Boolean] true if the location is an absolute URL
    def absolute_url?(location)
      location =~ Resolver::URL_PATTERN
    end
  end
end
