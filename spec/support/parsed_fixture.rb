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
      result = WSDL::Parser.import(wsdl_path, HTTPMock.new)

      @documents = result.documents
      @schemas = result.schemas
      @provenance = result.provenance
      @schema_import_errors = result.schema_import_errors
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
