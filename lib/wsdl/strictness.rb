# frozen_string_literal: true

module WSDL
  # Controls how strictly the library enforces WSDL/XSD correctness.
  #
  # Each setting independently controls a validation concern. Defaults are
  # strict ({.on}). Disable individual checks when working with imperfect
  # WSDLs rather than turning everything off.
  #
  # @example Disable only schema import strictness
  #   WSDL.parse(url, strictness: { schema_imports: false })
  #
  # @example Disable all strictness
  #   WSDL.parse(url, strictness: false)
  #
  # @example Derive with one setting changed
  #   WSDL::Strictness.new.with(schema_imports: false)
  #
  class Strictness
    # @param schema_imports [Boolean] raise on failed schema imports (default: true).
    #   When false, import failures are logged and skipped.
    # @param schema_references [Boolean] raise on unresolved type/element references
    #   (default: true). Covers unknown XSD built-in types and missing schema components.
    # @param operation_overloading [Boolean] reject operation overloading per WS-I Basic
    #   Profile R2304 (default: true). When false, overloaded operations are allowed and
    #   disambiguated via the +input_name:+ keyword.
    # @param request_validation [Boolean] validate request payloads against schema
    #   (default: true). Covers element order, required elements, unknown elements,
    #   namespace mismatches, and cardinality constraints.
    def initialize(schema_imports: true, schema_references: true,
                   operation_overloading: true, request_validation: true)
      @schema_imports = schema_imports ? true : false
      @schema_references = schema_references ? true : false
      @operation_overloading = operation_overloading ? true : false
      @request_validation = request_validation ? true : false
      freeze
    end

    # @return [Boolean] whether failed schema imports raise errors
    attr_reader :schema_imports

    # @return [Boolean] whether unresolved type/element references raise errors
    attr_reader :schema_references

    # @return [Boolean] whether operation overloading is rejected (WS-I R2304)
    attr_reader :operation_overloading

    # @return [Boolean] whether request payloads are validated against schema
    attr_reader :request_validation

    # Coerces a value into a Strictness instance.
    #
    # Accepts a Strictness object (returned as-is), a Hash of settings
    # (forwarded to {.new}), +true+ ({.on}), +false+ ({.off}), or +nil+.
    #
    # @param value [Strictness, Hash, Boolean, nil] the value to coerce
    # @return [Strictness, nil] the resolved Strictness, or nil if value is nil
    # @raise [ArgumentError] if the value type is not recognized
    def self.resolve(value)
      case value
      when Strictness then value
      when Hash then new(**value)
      when true then on
      when false then off
      when nil then nil
      else raise ArgumentError, "Cannot coerce #{value.inspect} into a Strictness"
      end
    end

    # Returns a new Strictness with all checks enabled.
    #
    # @return [Strictness]
    def self.on
      new
    end

    # Returns a new Strictness with all checks disabled.
    #
    # @return [Strictness]
    def self.off
      new(schema_imports: false, schema_references: false,
        operation_overloading: false, request_validation: false)
    end

    # Returns a new Strictness with the specified settings overridden.
    #
    # @param options [Hash] the settings to override
    # @return [Strictness]
    def with(**options)
      self.class.new(
        schema_imports: options.fetch(:schema_imports, @schema_imports),
        schema_references: options.fetch(:schema_references, @schema_references),
        operation_overloading: options.fetch(:operation_overloading, @operation_overloading),
        request_validation: options.fetch(:request_validation, @request_validation)
      )
    end

    # @return [Hash{Symbol => Boolean}]
    def to_h
      {
        schema_imports: @schema_imports,
        schema_references: @schema_references,
        operation_overloading: @operation_overloading,
        request_validation: @request_validation
      }
    end

    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && to_h == other.to_h
    end

    alias eql? ==

    # @return [Integer]
    def hash
      to_h.hash
    end

    # @return [String]
    def inspect
      settings = to_h.map { |k, v| "#{k}: #{v}" }.join(', ')
      "#<#{self.class} #{settings}>"
    end
  end
end
