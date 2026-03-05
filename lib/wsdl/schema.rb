# frozen_string_literal: true

require 'wsdl/schema/node'
require 'wsdl/schema/collection'
require 'wsdl/schema/definition'

module WSDL
  # XML Schema (XSD) parsing and representation.
  #
  # This module contains classes for parsing and traversing XML Schema
  # documents embedded within WSDL files or imported externally.
  #
  # The main classes are:
  # - {Node} - Unified representation of all XSD elements
  # - {Collection} - Aggregates multiple schema definitions
  # - {Definition} - Represents a single parsed xs:schema document
  #
  # @example Parsing schemas from a WSDL
  #   collection = Schema::Collection.new
  #   schema_nodes.each do |node|
  #     collection << Schema::Definition.new(node, collection)
  #   end
  #
  #   # Look up types
  #   user_type = collection.find_complex_type('http://example.com', 'User')
  #   user_type.elements.each { |el| puts el.name }
  #
  module Schema
  end
end
