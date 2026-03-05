# frozen_string_literal: true

require 'wsdl/log'

# WSDL toolkit for Ruby.
#
# This library provides tools for working with WSDL 1.1 documents, including
# parsing WSDL definitions, inspecting services and operations, and
# executing SOAP requests. WSDL 2.0 documents are detected and rejected
# with an {UnsupportedWSDLVersionError}.
#
# The main entry point is {Client}, which loads a WSDL document and
# provides access to its services and operations.
#
# @example Basic usage
#   client = WSDL::Client.new('http://example.com/service?wsdl')
#   client.services
#   # => {"ExampleService" => {ports: {"ExamplePort" => {type: "...", location: "..."}}}}
#
# @example Calling an operation
#   client = WSDL::Client.new('http://example.com/service?wsdl')
#   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
#   operation.prepare do
#     tag('GetData') { tag('id', 123) }
#   end
#   response = operation.invoke
#
module WSDL
  class << self
    # @return [Class] the HTTP adapter class (defaults to {HTTPClient})
    attr_reader :http_adapter

    # @return [Cache, nil] the cache instance, or nil if caching is disabled
    attr_accessor :cache

    # @return [Limits] the default limits instance
    attr_reader :limits

    # Returns the logger for the WSDL library.
    #
    # Defaults to a silent {Log::NullLogger} that discards all output.
    # Assign a custom logger via {.logger=}.
    #
    # @example Enable warn-level output to stdout
    #   require 'logger'
    #   WSDL.logger = Logger.new($stdout, level: :warn)
    #
    # @return [Logger, Log::NullLogger]
    attr_reader :logger

    # Sets the logger for the WSDL library. Pass nil to restore the default.
    #
    # Assign any +Logger+-compatible object (must respond to
    # +debug+, +info+, +warn+, +error+, +fatal+).
    #
    # @example Use Rails logger
    #   WSDL.logger = Rails.logger
    def logger=(value)
      @logger = value || Log::NullLogger.new
    end

    # Sets the HTTP adapter class. Pass nil to restore the default.
    def http_adapter=(adapter)
      @http_adapter = adapter || HTTPClient
    end

    # Sets the default resource limits. Pass nil to restore defaults.
    def limits=(value)
      @limits = value || Limits.new
    end
  end

  # Load core components
  require 'wsdl/version'
  require 'wsdl/ns'
  require 'wsdl/errors'
  require 'wsdl/qname'
  require 'wsdl/formatting'
  require 'wsdl/limits'
  require 'wsdl/parse_options'
  require 'wsdl/source'
  require 'wsdl/cache'
  require 'wsdl/config'
  require 'wsdl/http_response'
  require 'wsdl/httpclient'

  # Load XML utilities
  require 'wsdl/xml/attribute'
  require 'wsdl/xml/element'
  require 'wsdl/xml/element_builder'

  # Load schema module
  require 'wsdl/schema'

  # Load parser module (WSDL/XSD parsing)
  require 'wsdl/parser'

  # Load response handling
  require 'wsdl/response/type_coercer'
  require 'wsdl/response/parser'
  require 'wsdl/response'

  # Load security module
  require 'wsdl/security'

  # Load operation contract and request pipeline
  require 'wsdl/contract'
  require 'wsdl/request'

  # Load operation (public API)
  require 'wsdl/operation'

  # Load client (main entry point)
  require 'wsdl/client'

  # Initialize defaults. These must be set before spawning threads.
  # Reconfigure via the corresponding writer (e.g. WSDL.cache = nil).
  @http_adapter = HTTPClient
  @cache        = Cache.new
  @limits       = Limits.new
  @logger       = Log::NullLogger.new
end
