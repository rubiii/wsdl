# frozen_string_literal: true

module WSDL
  module Parser
    # Result of resolving and importing a WSDL document.
    #
    # Returned by {Parser.import} and consumed by {Definition::Builder}
    # or directly by callers that need the intermediate parse structures
    # without building a full {Definition}.
    #
    # @example Accessing parsed structures
    #   result = WSDL::Parser.import('service.wsdl', http)
    #   result.documents  # => Parser::DocumentCollection
    #   result.schemas    # => Schema::Collection
    #
    # @api private
    ImportResult = Data.define(:documents, :schemas, :provenance, :schema_import_errors)
  end
end
