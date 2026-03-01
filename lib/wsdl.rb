# frozen_string_literal: true

require 'logging'

require 'wsdl/version'
require 'wsdl/errors'
require 'wsdl/cache'
require 'wsdl/definition'
require 'wsdl/operation'
require 'wsdl/httpclient'
require 'wsdl/security'

# Main entry point for working with WSDL documents.
#
# This class provides a high-level interface for parsing WSDL documents,
# inspecting services and operations, and executing SOAP requests.
#
# @example Basic usage
#   wsdl = WSDL.new('http://example.com/service?wsdl')
#   wsdl.services
#   # => {"ExampleService" => {ports: {"ExamplePort" => {type: "...", location: "..."}}}}
#
# @example Calling an operation
#   operation = wsdl.operation('ExampleService', 'ExamplePort', 'GetData')
#   operation.body = { id: 123 }
#   response = operation.call
#
class WSDL
  # XML Schema namespace URI
  NS_XSD  = 'http://www.w3.org/2001/XMLSchema'

  # WSDL namespace URI
  NS_WSDL = 'http://schemas.xmlsoap.org/wsdl/'

  # SOAP 1.1 namespace URI
  NS_SOAP_1_1 = 'http://schemas.xmlsoap.org/wsdl/soap/'

  # SOAP 1.2 namespace URI
  NS_SOAP_1_2 = 'http://schemas.xmlsoap.org/wsdl/soap12/'

  # Returns the HTTP adapter class to use for requests.
  #
  # @return [Class] the HTTP adapter class (defaults to {HTTPClient})
  def self.http_adapter
    @http_adapter ||= HTTPClient
  end

  # Sets the HTTP adapter class to use for requests.
  #
  # @param adapter [Class] an HTTP adapter class that responds to `new`
  # @return [Class] the adapter class
  class << self
    attr_writer :http_adapter
  end

  # Returns the default cache instance for parsed WSDL definitions.
  #
  # By default, a shared {Cache} instance is used to avoid redundant
  # HTTP requests and parsing when creating multiple WSDL instances
  # for the same document.
  #
  # @return [Cache, nil] the cache instance, or nil if caching is disabled
  def self.cache
    return @cache if defined?(@cache)

    @cache = Cache.new
  end

  # Sets the default cache instance.
  #
  # @param cache [Cache, nil] a cache instance, or nil to disable caching
  # @return [Cache, nil] the cache instance
  #
  # @example Using a custom cache with TTL
  #   WSDL.cache = WSDL::Cache.new(ttl: 3600)
  #
  # @example Disabling caching globally
  #   WSDL.cache = nil
  class << self
    attr_writer :cache
  end

  # Creates a new WSDL instance.
  #
  # @param wsdl [String] a URL, file path, or raw XML string of the WSDL document
  # @param http [Object, nil] an optional HTTP adapter instance
  #   (defaults to a new instance of {.http_adapter})
  # @param pretty_print [Boolean] whether to format XML output with indentation
  #   and margins. Set to `false` for whitespace-sensitive SOAP servers.
  #   Defaults to `true`.
  # @param cache [Cache, nil, :default] the cache to use for parsed definitions.
  #   Defaults to {.cache}. Pass `nil` to disable caching for this instance.
  #
  # @example Basic usage
  #   wsdl = WSDL.new('http://example.com/service?wsdl')
  #
  # @example With custom HTTP adapter
  #   wsdl = WSDL.new('http://example.com/service?wsdl', http: my_adapter)
  #
  # @example Disable pretty printing for whitespace-sensitive servers
  #   wsdl = WSDL.new('http://example.com/service?wsdl', pretty_print: false)
  #
  # @example Disable caching for this instance
  #   wsdl = WSDL.new('http://example.com/service?wsdl', cache: nil)
  #
  # @example Use a custom cache with TTL
  #   my_cache = WSDL::Cache.new(ttl: 3600)
  #   wsdl = WSDL.new('http://example.com/service?wsdl', cache: my_cache)
  def initialize(wsdl, http: nil, pretty_print: true, cache: :default)
    @http = http || new_http_client
    @wsdl = load_definition(wsdl, cache)
    @pretty_print = pretty_print
  end

  # Returns the Definition instance containing parsed WSDL data.
  #
  # @return [Definition] the WSDL definition
  attr_reader :wsdl

  # Returns whether pretty printing is enabled for XML output.
  #
  # @return [Boolean] true if XML will be formatted with indentation
  attr_reader :pretty_print

  # Returns the HTTP adapter's client instance for configuration.
  #
  # @return [Object] the underlying HTTP client
  def http
    @http.client
  end

  # Returns the services and ports defined by the WSDL.
  #
  # @return [Hash] a hash of service names to their port definitions
  # @example
  #   wsdl.services
  #   # => {"ServiceName" => {ports: {"PortName" => {type: "...", location: "..."}}}}
  def services
    @wsdl.services
  end

  # Returns an array of operation names for a service and port.
  #
  # @param service_name [String, Symbol] the name of the service
  # @param port_name [String, Symbol] the name of the port
  # @return [Array<String>] the list of operation names
  # @raise [ArgumentError] if the service or port does not exist
  def operations(service_name, port_name)
    @wsdl.operations(service_name.to_s, port_name.to_s)
  end

  # Returns an Operation instance for calling a SOAP operation.
  #
  # @param service_name [String, Symbol] the name of the service
  # @param port_name [String, Symbol] the name of the port
  # @param operation_name [String, Symbol] the name of the operation
  # @return [Operation] the operation instance
  # @raise [ArgumentError] if the service, port, or operation does not exist
  # @raise [UnsupportedStyleError] if the operation uses an unsupported style (e.g., rpc/encoded)
  def operation(service_name, port_name, operation_name)
    operation = @wsdl.operation(service_name.to_s, port_name.to_s, operation_name.to_s)
    verify_operation_style! operation

    Operation.new(operation, @wsdl, @http, pretty_print:)
  end

  private

  # Loads the WSDL definition, using cache if available.
  #
  # @param wsdl [String] the WSDL location or content
  # @param cache [Cache, nil, :default] the cache to use
  # @return [Definition] the parsed definition
  def load_definition(wsdl, cache)
    cache = self.class.cache if cache == :default

    if cache
      cache.fetch(wsdl) { Definition.new(wsdl, @http) }
    else
      Definition.new(wsdl, @http)
    end
  end

  # Returns a new instance of the HTTP adapter.
  #
  # @return [Object] a new HTTP adapter instance
  def new_http_client
    self.class.http_adapter.new
  end

  # Raises if the operation style is not supported.
  #
  # @param operation [Definition::Operation] the operation to verify
  # @raise [UnsupportedStyleError] if the operation style is not supported
  def verify_operation_style!(operation)
    return unless operation.input_style == 'rpc/encoded'

    raise UnsupportedStyleError,
          "#{operation.name.inspect} is an #{operation.input_style.inspect} style operation.\n" \
          'Currently this style is not supported.'
  end
end
