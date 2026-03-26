# frozen_string_literal: true

module WSDL
  # Configuration for resource limits to prevent denial-of-service attacks.
  #
  # This class provides sensible defaults that work for most WSDL documents
  # while protecting against malicious or malformed documents that could
  # exhaust system resources.
  #
  # The library already protects against XXE, SSRF, and path traversal attacks.
  # These limits add protection against resource exhaustion attacks.
  #
  # @example Using default limits
  #   definition = WSDL.parse('http://example.com/service?wsdl')
  #
  # @example Customizing limits
  #   definition = WSDL.parse(url, limits: { max_schemas: 100 })
  #
  # @example Customizing with a Limits object
  #   custom = WSDL::Limits.new(max_document_size: 20 * 1024 * 1024)
  #   definition = WSDL.parse(url, limits: custom)
  #
  # @example Disabling a specific limit
  #   definition = WSDL.parse(url, limits: { max_schemas: nil })
  #
  class Limits
    # Default maximum size for a single WSDL or schema document (10 MB).
    DEFAULT_MAX_DOCUMENT_SIZE = 10 * 1024 * 1024

    # Default maximum cumulative bytes downloaded across all documents (50 MB).
    DEFAULT_MAX_TOTAL_DOWNLOAD_SIZE = 50 * 1024 * 1024

    # Default maximum number of schema definitions allowed.
    DEFAULT_MAX_SCHEMAS = 50

    # Default maximum child elements in a complex type.
    DEFAULT_MAX_ELEMENTS_PER_TYPE = 500

    # Default maximum attributes on an XML element.
    DEFAULT_MAX_ATTRIBUTES_PER_ELEMENT = 100

    # Default maximum depth of type inheritance/nesting.
    DEFAULT_MAX_TYPE_NESTING_DEPTH = 50

    # Default maximum total elements in request envelope construction.
    DEFAULT_MAX_REQUEST_ELEMENTS = 10_000

    # Default maximum request envelope nesting depth.
    DEFAULT_MAX_REQUEST_DEPTH = 100

    # Default maximum total attributes in request envelope construction.
    DEFAULT_MAX_REQUEST_ATTRIBUTES = 1_000

    # Default maximum iterations for resolving schema imports and includes.
    DEFAULT_MAX_SCHEMA_IMPORT_ITERATIONS = 100

    # Default maximum size for a SOAP response body (10 MB).
    DEFAULT_MAX_RESPONSE_SIZE = 10 * 1024 * 1024

    # Coerces a value into a Limits instance.
    #
    # Accepts a Limits object (returned as-is), a Hash of settings
    # (forwarded to {.new}), or +nil+.
    #
    # @param value [Limits, Hash, nil] the value to coerce
    # @return [Limits, nil] the resolved Limits, or nil if value is nil
    # @raise [ArgumentError] if the value type is not recognized
    def self.resolve(value)
      case value
      when Limits then value
      when Hash then new(**value)
      when nil then nil
      else raise ArgumentError, "Cannot coerce #{value.inspect} into a Limits"
      end
    end

    # Creates a new Limits instance with the specified resource limits.
    #
    # @param max_document_size [Integer, nil] maximum size in bytes for a single WSDL/schema
    #   document. Set to nil to disable this limit. Default: 10 MB.
    # @param max_total_download_size [Integer, nil] maximum cumulative bytes downloaded
    #   across all WSDL and schema documents. Set to nil to disable. Default: 50 MB.
    # @param max_schemas [Integer, nil] maximum number of schema definitions allowed.
    #   Set to nil to disable. Default: 50.
    # @param max_elements_per_type [Integer, nil] maximum child elements in a complex type.
    #   Set to nil to disable. Default: 500.
    # @param max_attributes_per_element [Integer, nil] maximum attributes on an XML element.
    #   Set to nil to disable. Default: 100.
    # @param max_type_nesting_depth [Integer, nil] maximum depth of type inheritance/nesting.
    #   Set to nil to disable. Default: 50.
    # @param max_request_elements [Integer, nil] maximum total elements allowed in request envelope.
    #   Set to nil to disable. Default: 10,000.
    # @param max_request_depth [Integer, nil] maximum request envelope nesting depth.
    #   Set to nil to disable. Default: 100.
    # @param max_request_attributes [Integer, nil] maximum total attributes in request envelope.
    #   Set to nil to disable. Default: 1,000.
    # @param max_schema_import_iterations [Integer, nil] maximum iterations for resolving
    #   schema imports and includes. Set to nil to disable. Default: 100.
    # @param max_response_size [Integer, nil] maximum size in bytes for a SOAP response body.
    #   Set to nil to disable this limit. Default: 10 MB.
    #
    # rubocop:disable Metrics/ParameterLists
    def initialize(
      max_document_size: DEFAULT_MAX_DOCUMENT_SIZE,
      max_total_download_size: DEFAULT_MAX_TOTAL_DOWNLOAD_SIZE,
      max_schemas: DEFAULT_MAX_SCHEMAS,
      max_elements_per_type: DEFAULT_MAX_ELEMENTS_PER_TYPE,
      max_attributes_per_element: DEFAULT_MAX_ATTRIBUTES_PER_ELEMENT,
      max_type_nesting_depth: DEFAULT_MAX_TYPE_NESTING_DEPTH,
      max_request_elements: DEFAULT_MAX_REQUEST_ELEMENTS,
      max_request_depth: DEFAULT_MAX_REQUEST_DEPTH,
      max_request_attributes: DEFAULT_MAX_REQUEST_ATTRIBUTES,
      max_schema_import_iterations: DEFAULT_MAX_SCHEMA_IMPORT_ITERATIONS,
      max_response_size: DEFAULT_MAX_RESPONSE_SIZE
    )
      # rubocop:enable Metrics/ParameterLists
      @max_document_size = max_document_size
      @max_total_download_size = max_total_download_size
      @max_schemas = max_schemas
      @max_elements_per_type = max_elements_per_type
      @max_attributes_per_element = max_attributes_per_element
      @max_type_nesting_depth = max_type_nesting_depth
      @max_request_elements = max_request_elements
      @max_request_depth = max_request_depth
      @max_request_attributes = max_request_attributes
      @max_schema_import_iterations = max_schema_import_iterations
      @max_response_size = max_response_size

      freeze
    end

    # @return [Integer, nil] maximum size in bytes for a single WSDL/schema document
    attr_reader :max_document_size

    # @return [Integer, nil] maximum cumulative bytes downloaded
    attr_reader :max_total_download_size

    # @return [Integer, nil] maximum number of schema definitions
    attr_reader :max_schemas

    # @return [Integer, nil] maximum child elements in a complex type
    attr_reader :max_elements_per_type

    # @return [Integer, nil] maximum attributes on an XML element
    attr_reader :max_attributes_per_element

    # @return [Integer, nil] maximum depth of type inheritance/nesting
    attr_reader :max_type_nesting_depth

    # @return [Integer, nil] maximum total elements in request envelope
    attr_reader :max_request_elements

    # @return [Integer, nil] maximum request envelope nesting depth
    attr_reader :max_request_depth

    # @return [Integer, nil] maximum total attributes in request envelope
    attr_reader :max_request_attributes

    # @return [Integer, nil] maximum iterations for resolving schema imports and includes
    attr_reader :max_schema_import_iterations

    # @return [Integer, nil] maximum size in bytes for a SOAP response body
    attr_reader :max_response_size

    # Creates a new Limits instance with some values changed.
    #
    # @param options [Hash] the limits to override
    # @option options [Integer, nil] :max_document_size
    # @option options [Integer, nil] :max_total_download_size
    # @option options [Integer, nil] :max_schemas
    # @option options [Integer, nil] :max_elements_per_type
    # @option options [Integer, nil] :max_attributes_per_element
    # @option options [Integer, nil] :max_type_nesting_depth
    # @option options [Integer, nil] :max_request_elements
    # @option options [Integer, nil] :max_request_depth
    # @option options [Integer, nil] :max_request_attributes
    # @option options [Integer, nil] :max_schema_import_iterations
    # @option options [Integer, nil] :max_response_size
    # @return [Limits] a new Limits instance with the specified changes
    #
    # @example Increase document size limit
    #   new_limits = limits.with(max_document_size: 20 * 1024 * 1024)
    #
    # @example Disable schema count limit
    #   new_limits = limits.with(max_schemas: nil)
    #
    def with(**options)
      self.class.new(
        max_document_size: options.fetch(:max_document_size, @max_document_size),
        max_total_download_size: options.fetch(:max_total_download_size, @max_total_download_size),
        max_schemas: options.fetch(:max_schemas, @max_schemas),
        max_elements_per_type: options.fetch(:max_elements_per_type, @max_elements_per_type),
        max_attributes_per_element: options.fetch(:max_attributes_per_element, @max_attributes_per_element),
        max_type_nesting_depth: options.fetch(:max_type_nesting_depth, @max_type_nesting_depth),
        max_request_elements: options.fetch(:max_request_elements, @max_request_elements),
        max_request_depth: options.fetch(:max_request_depth, @max_request_depth),
        max_request_attributes: options.fetch(:max_request_attributes, @max_request_attributes),
        max_schema_import_iterations: options.fetch(:max_schema_import_iterations, @max_schema_import_iterations),
        max_response_size: options.fetch(:max_response_size, @max_response_size)
      )
    end

    # Returns a hash representation of the limits.
    #
    # @return [Hash{Symbol => Integer, nil}] the limits as a hash
    #
    def to_h
      {
        max_document_size: @max_document_size,
        max_total_download_size: @max_total_download_size,
        max_schemas: @max_schemas,
        max_elements_per_type: @max_elements_per_type,
        max_attributes_per_element: @max_attributes_per_element,
        max_type_nesting_depth: @max_type_nesting_depth,
        max_request_elements: @max_request_elements,
        max_request_depth: @max_request_depth,
        max_request_attributes: @max_request_attributes,
        max_schema_import_iterations: @max_schema_import_iterations,
        max_response_size: @max_response_size
      }
    end

    # Returns a human-readable string representation.
    #
    # @return [String] the limits formatted for display
    #
    def inspect
      parts = {
        max_document_size: Formatting.format_bytes(@max_document_size),
        max_total_download_size: Formatting.format_bytes(@max_total_download_size),
        max_schemas: limit_value(@max_schemas),
        max_elements_per_type: limit_value(@max_elements_per_type),
        max_attributes_per_element: limit_value(@max_attributes_per_element),
        max_type_nesting_depth: limit_value(@max_type_nesting_depth),
        max_request_elements: limit_value(@max_request_elements),
        max_request_depth: limit_value(@max_request_depth),
        max_request_attributes: limit_value(@max_request_attributes),
        max_schema_import_iterations: limit_value(@max_schema_import_iterations),
        max_response_size: Formatting.format_bytes(@max_response_size)
      }.map { |key, value| "#{key}=#{value}" }.join(' ')

      "#<#{self.class.name} #{parts}>"
    end

    # Checks equality with another Limits instance.
    #
    # @param other [Object] the object to compare
    # @return [Boolean] true if equal
    #
    def ==(other)
      return false unless other.is_a?(Limits)

      to_h == other.to_h
    end

    alias eql? ==

    # Returns a hash code for use in Hash keys.
    #
    # @return [Integer] the hash code
    #
    def hash
      to_h.hash
    end

    private

    # Formats numeric limits for human-readable output.
    #
    # @param value [Integer, nil] configured limit value
    # @return [Integer, String] numeric value or `'unlimited'` for nil
    def limit_value(value)
      value || 'unlimited'
    end
  end
end
