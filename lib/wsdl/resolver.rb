# frozen_string_literal: true

require 'wsdl/resolver/source'
require 'wsdl/resolver/loader'
require 'wsdl/resolver/importer'

module WSDL
  # I/O and orchestration for resolving WSDL documents and their dependencies.
  #
  # Contains the classes responsible for classifying input sources, fetching
  # documents from URLs or the filesystem, and recursively importing schemas.
  # The Parser module handles XML parsing; this module handles everything
  # before and around it.
  #
  # @api private
  module Resolver
  end
end
