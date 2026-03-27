# frozen_string_literal: true

module SpecSupport
  # Pre-parses a WSDL fixture into its intermediate structures for
  # performance specs that need to measure individual pipeline stages
  # (e.g. Definition::Builder, Schema::Node traversal) in isolation.
  #
  # @example
  #   parsed = ParsedFixture.new('wsdl/economic')
  #   parsed.schemas   # => Schema::Collection
  #   parsed.documents # => Parser::DocumentCollection
  class ParsedFixture
    attr_reader :documents, :schemas, :provenance, :schema_import_errors

    def initialize(fixture_path)
      wsdl_path = Fixture.path(fixture_path)
      http = HTTPMock.new

      @documents = WSDL::Parser::DocumentCollection.new
      @schemas = WSDL::Schema::Collection.new

      source = WSDL::Resolver::Source.validate_wsdl!(wsdl_path)
      sandbox_paths = source.resolve_sandbox_paths(nil)
      loader = WSDL::Resolver::Loader.new(http, sandbox_paths:, limits: WSDL::Limits.new)
      importer = WSDL::Resolver::Importer.new(loader, @documents, @schemas, WSDL::ParseOptions.default)
      importer.import(source.value)

      @provenance = importer.provenance.freeze
      @schema_import_errors = importer.schema_import_errors.freeze
    end

    # Finds the first complex type with children in the schema collection.
    #
    # @return [WSDL::Schema::Node, nil]
    def find_complex_type_with_children
      @schemas.each do |definition|
        definition.complex_types.each_value do |type|
          return type unless type.children.empty?
        end
      end
      nil
    end
  end
end
