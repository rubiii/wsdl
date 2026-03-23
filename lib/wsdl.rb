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
    # @return [Class] the HTTP adapter class (defaults to {HTTPAdapter})
    attr_reader :http_adapter

    # The parser cache instance, or +nil+ if caching is disabled.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads.
    #
    # @return [Cache, nil]
    attr_accessor :cache

    # @return [Limits] the default limits instance
    attr_reader :limits

    # @return [Strictness] the default strictness settings
    attr_reader :strictness

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

    # Sets the HTTP adapter class. Pass +nil+ to restore the default.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads. Changing it after clients exist may
    # cause inconsistent behavior.
    #
    # @example
    #   WSDL.http_adapter = MyHTTPAdapter
    #
    # @param adapter [Class, nil] an HTTP adapter class, or +nil+ to reset
    # @see file:docs/core/configuration.md#http-adapter HTTP Adapter docs
    def http_adapter=(adapter)
      @http_adapter = adapter || HTTPAdapter
    end

    # Sets the default resource limits. Pass +nil+ to restore defaults.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads.
    #
    # @example
    #   WSDL.limits = WSDL::Limits.new(max_schemas: 200)
    #
    # @param value [Limits, Hash, nil] a limits instance, hash of settings, or +nil+ to reset
    # @see Limits
    def limits=(value)
      @limits = Limits.resolve(value) || Limits.new
    end

    # Sets the default strictness settings. Pass +nil+ to restore defaults.
    #
    # This is a global setting. Set it once at boot time, before creating
    # any clients or spawning threads.
    #
    # @example
    #   WSDL.strictness = { schema_imports: false }
    #
    # @param value [Strictness, Hash, Boolean, nil] a strictness instance, hash, boolean, or +nil+ to reset
    # @see Strictness
    def strictness=(value)
      @strictness = Strictness.resolve(value) || Strictness.new
    end

    # Parses a WSDL and returns a frozen {Definition}.
    #
    # Accepts a URL, file path, or inline XML string. Uses the existing
    # parsing pipeline internally and converts the result to a {Definition}
    # that can be cached, serialized, and passed to {Client.new}.
    #
    # @param source [String] WSDL URL, file path, or inline XML
    # @param http [Object, nil] HTTP adapter for fetching (defaults to {.http_adapter})
    # @param cache [Cache, nil, false] cache instance (defaults to {.cache})
    # @param strictness [Strictness, Hash, Boolean, nil] strictness settings
    # @param sandbox_paths [Array<String>, nil] allowed directories for file access
    # @param limits [Limits, Hash, nil] resource limits
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
    def parse(source, http: nil, cache: nil, strictness: nil, sandbox_paths: nil, limits: nil) # rubocop:disable Metrics/ParameterLists
      http ||= http_adapter.new
      config = Config.new(strictness:, sandbox_paths:, limits:)

      source_obj = Source.validate_wsdl!(source)
      resolved_sandbox = source_obj.resolve_sandbox_paths(config.sandbox_paths)

      parser_result = Parser::CachedResult.load(
        wsdl: source,
        http:,
        cache:,
        parse_options: ParseOptions.new(
          sandbox_paths: resolved_sandbox,
          limits: config.limits,
          strictness: config.strictness
        )
      )

      Definition::Builder.new(parser_result).build
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
  require 'wsdl/source'
  require 'wsdl/cache'
  require 'wsdl/config'
  require 'wsdl/http_response'
  require 'wsdl/http_adapter'

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
  # Reconfigure via the corresponding writer (e.g. WSDL.cache = nil).
  @http_adapter = HTTPAdapter
  @cache        = Cache.new(max_entries: 50)
  @limits       = Limits.new
  @strictness   = Strictness.new
  @logger       = Log::NullLogger.new
end
