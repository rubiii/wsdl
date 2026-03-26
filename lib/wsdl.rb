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
#   definition = WSDL.parse('http://example.com/service?wsdl')
#   client = WSDL::Client.new(definition)
#   client.services
#   # => {"ExampleService" => {ports: {"ExamplePort" => {type: "...", location: "..."}}}}
#
# @example Calling an operation
#   definition = WSDL.parse('http://example.com/service?wsdl')
#   client = WSDL::Client.new(definition)
#   operation = client.operation('ExampleService', 'ExamplePort', 'GetData')
#   operation.prepare do
#     tag('GetData') { tag('id', 123) }
#   end
#   response = operation.invoke
#
module WSDL
  class << self
    # @return [Class] the HTTP client class (defaults to {HTTP::Client})
    attr_reader :http_client

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

    # Sets the logger for the WSDL library. Pass +nil+ to restore the default.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads.
    #
    # Assign any +Logger+-compatible object (must respond to
    # +debug+, +info+, +warn+, +error+, +fatal+).
    #
    # @example Use Rails logger
    #   WSDL.logger = Rails.logger
    #
    # @param value [Logger, nil] a logger instance, or +nil+ to reset
    def logger=(value)
      @logger = value || Log::NullLogger.new
    end

    # Sets the HTTP client class. Pass +nil+ to restore the default.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads. Changing it after clients exist may
    # cause inconsistent behavior.
    #
    # @example
    #   WSDL.http_client = MyHTTPClient
    #
    # @param client [Class, nil] an HTTP client class, or +nil+ to reset
    # @see file:docs/core/configuration.md#http-client HTTP client docs
    def http_client=(client)
      @http_client = client || HTTP::Client
    end

    # Parses a WSDL and returns a frozen {Definition}.
    #
    # Accepts a URL or file path. Uses the parsing pipeline internally
    # and returns a {Definition} that can be serialized and passed to
    # {Client.new}.
    #
    # @param source [String] WSDL URL or file path
    # @param http [Object, nil] HTTP client for fetching (defaults to {.http_client})
    # @param strictness [Strictness, Hash, Boolean, nil] strictness settings
    #   (defaults to all strict)
    # @param sandbox_paths [Array<String>, nil] allowed directories for file access
    # @param limits [Limits, Hash, nil] resource limits (defaults to {Limits} defaults)
    # @return [Definition] the frozen definition
    #
    # @example Parse from URL
    #   definition = WSDL.parse('http://example.com/service?wsdl')
    #
    # @example Parse from file
    #   definition = WSDL.parse('/path/to/service.wsdl')
    #
    # @example With options
    #   definition = WSDL.parse(url, strictness: false, limits: { max_schemas: 200 })
    #
    def parse(source, http: nil, strictness: nil, sandbox_paths: nil, limits: nil)
      http ||= http_client.new

      parse_options = ParseOptions.new(
        sandbox_paths:,
        limits: Limits.resolve(limits) || Limits.new,
        strictness: Strictness.resolve(strictness) || Strictness.new
      )
      Parser.parse(source, http, parse_options)
    end

    # Restores a {Definition} from a serialized Hash.
    #
    # The hash must have been produced by {Definition#to_h} or parsed
    # from {Definition#to_json}. Raises if the schema version doesn't
    # match the current library version.
    #
    # @param hash [Hash{String => Object}] serialized definition hash
    # @return [Definition] the restored definition
    # @raise [ArgumentError] if the schema version doesn't match
    #
    # @example
    #   cached = JSON.parse(File.read('service.json'))
    #   definition = WSDL.load(cached)
    #
    def load(hash)
      Definition.from_h(hash)
    end
  end

  # Load core components
  require 'wsdl/version'
  require 'wsdl/ns'
  require 'wsdl/errors'
  require 'wsdl/qname'
  require 'wsdl/formatting'
  require 'wsdl/limits'
  require 'wsdl/strictness'
  require 'wsdl/parse_options'
  require 'wsdl/resolver'
  require 'wsdl/config'
  require 'wsdl/http'

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

  # Load definition IR
  require 'wsdl/definition'

  # Load operation contract and request pipeline
  require 'wsdl/contract'
  require 'wsdl/request'

  # Load operation (public API)
  require 'wsdl/operation'

  # Load client (main entry point)
  require 'wsdl/client'

  # Initialize defaults. These must be set before spawning threads.
  @http_client = HTTP::Client
  @logger = Log::NullLogger.new
end
