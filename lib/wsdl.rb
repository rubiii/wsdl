# frozen_string_literal: true

require 'logging'

# WSDL toolkit for Ruby.
#
# This library provides tools for working with WSDL documents, including
# parsing WSDL definitions, inspecting services and operations, and
# executing SOAP requests.
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
#   operation.body = { id: 123 }
#   response = operation.call
#
# @example Using example messages
#   operation = client.operation('Service', 'Port', 'CreateUser')
#   operation.body = operation.example_body
#   operation.body[:user][:name] = 'John Doe'
#   operation.body[:user][:email] = 'john@example.com'
#   response = operation.call
#
# @example WS-Security with UsernameToken
#   operation = client.operation('Service', 'Port', 'SecureOperation')
#   operation.security.username_token('user', 'secret')
#   response = operation.call
#
module WSDL
  # Returns the HTTP adapter class to use for requests.
  #
  # @return [Class] the HTTP adapter class (defaults to {HTTPClient})
  #
  def self.http_adapter
    @http_adapter ||= HTTPClient
  end

  # Sets the HTTP adapter class to use for requests.
  #
  # @param adapter [Class] an HTTP adapter class that responds to `new`
  # @return [Class] the adapter class
  #
  class << self
    attr_writer :http_adapter
  end

  # Returns the default cache instance for parsed WSDL definitions.
  #
  # By default, a shared {Cache} instance is used to avoid redundant
  # HTTP requests and parsing when creating multiple Client instances
  # for the same document.
  #
  # @return [Cache, nil] the cache instance, or nil if caching is disabled
  #
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
  #
  class << self
    attr_writer :cache
  end

  # Returns the default resource limits for WSDL parsing.
  #
  # By default, a {Limits} instance with sensible defaults is used
  # to prevent resource exhaustion from malicious WSDL documents.
  #
  # @return [Limits] the default limits instance
  #
  def self.limits
    @limits ||= Limits.new
  end

  # Sets the default resource limits.
  #
  # @param limits [Limits] a limits instance
  # @return [Limits] the limits instance
  #
  # @example Increasing the document size limit
  #   WSDL.limits = WSDL::Limits.new(max_document_size: 20 * 1024 * 1024)
  #
  # @example Modifying a single limit
  #   WSDL.limits = WSDL.limits.with(max_schemas: 100)
  #
  class << self
    attr_writer :limits
  end

  # Load core components
  require 'wsdl/version'
  require 'wsdl/ns'
  require 'wsdl/errors'
  require 'wsdl/formatting'
  require 'wsdl/limits'
  require 'wsdl/cache'
  require 'wsdl/httpclient'

  # Load XML utilities
  require 'wsdl/xml/attribute'
  require 'wsdl/xml/element'
  require 'wsdl/xml/element_builder'

  # Load schema module
  require 'wsdl/schema'

  # Load parser module (WSDL/XSD parsing)
  require 'wsdl/parser'

  # Load builder module (SOAP envelope building)
  require 'wsdl/builder'

  # Load response handling
  require 'wsdl/response/hash_converter'
  require 'wsdl/response'

  # Load operation (public API)
  require 'wsdl/operation'

  # Load security module
  require 'wsdl/security'

  # Load client (main entry point)
  require 'wsdl/client'
end
