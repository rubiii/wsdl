# frozen_string_literal: true

require 'json'
require 'wsdl/definition/element_hash'
require 'wsdl/definition/operation_proxy'
require 'wsdl/definition/builder'

module WSDL
  # Abstract representation of a parsed WSDL service.
  #
  # A Definition is a frozen, serializable snapshot of everything the library
  # knows about a WSDL service — its services, ports, operations, and message
  # structures stored as plain hashes. It serves as the intermediate
  # representation (IR) that downstream consumers (Client, Operation, Response)
  # operate on.
  #
  # Create a Definition via {WSDL.parse} or restore one from a cached hash
  # via {WSDL.load}.
  #
  # @example Parse and cache
  #   definition = WSDL.parse('http://example.com?wsdl')
  #   File.write('cache.json', definition.to_json)
  #
  # @example Restore from cache
  #   definition = WSDL.load(JSON.parse(File.read('cache.json')))
  #
  # @see WSDL.parse
  # @see WSDL.load
  #
  class Definition
    # Creates a new Definition from internal data.
    #
    # This constructor is intended for internal use by {Builder} and {.from_h}.
    # Users should create Definitions via {WSDL.parse} or {WSDL.load}.
    #
    # @param data [Hash{Symbol => Object}] the internal definition data
    # @api private
    def initialize(data)
      @data = deep_freeze(data)
      freeze
    end

    # Returns the schema version of this Definition's internal format.
    #
    # @return [Integer]
    def schema_version
      @data[:schema_version]
    end

    # Returns the name of the primary service.
    #
    # @return [String, nil] the service name
    def service_name
      @data[:service_name]
    end

    # Returns the content-based fingerprint for this Definition.
    #
    # The fingerprint is derived from all source digests and statuses.
    # It changes when any source document changes or when a previously
    # failing import starts resolving (or vice versa).
    #
    # @return [String] SHA-256 fingerprint (e.g. "sha256:a1b2c3...")
    def fingerprint
      @data[:fingerprint]
    end

    # Returns source provenance for all documents fetched during parsing.
    #
    # Each entry records the location, resolution status, content digest,
    # and any error. Provides transparency into what was resolved and
    # enables change detection.
    #
    # @return [Array<Hash{Symbol => Object}>] provenance entries
    #
    # @example
    #   definition.sources
    #   # => [{ location: "http://...", status: :resolved, digest: "sha256:...", error: nil },
    #   #     { location: "http://...", status: :failed, digest: nil, error: "404 Not Found" }]
    def sources
      @data[:sources]
    end

    # Serializes this Definition to a plain Hash.
    #
    # The hash is suitable for JSON serialization and can be restored
    # via {WSDL.load} or {.from_h}.
    #
    # @return [Hash{String => Object}] serializable hash with string keys
    def to_h
      serialize(@data)
    end

    # Serializes this Definition to a JSON string.
    #
    # @return [String] JSON representation
    def to_json(*)
      JSON.generate(to_h, *)
    end

    # Restores a Definition from a serialized Hash.
    #
    # Validates the schema version and raises if it doesn't match
    # the current library version.
    #
    # @param hash [Hash{String => Object}] serialized hash from {#to_h}
    # @return [Definition] the restored definition
    # @raise [ArgumentError] if the schema version doesn't match
    def self.from_h(hash)
      version = hash['schema_version'] || hash[:schema_version]

      unless version == Builder::SCHEMA_VERSION
        raise ArgumentError,
              "Definition schema version mismatch: expected #{Builder::SCHEMA_VERSION}, " \
              "got #{version.inspect}. Please re-parse the WSDL with WSDL.parse."
      end

      new(deserialize(hash))
    end

    private

    # Deep-freezes a nested hash/array structure.
    #
    # @param obj [Object] the object to deep-freeze
    # @return [Object] the frozen object
    def deep_freeze(obj)
      case obj
      when Hash
        obj.each_value do |v|
          deep_freeze(v)
        end
        obj.freeze
      when Array
        obj.each do |v|
          deep_freeze(v)
        end
        obj.freeze
      else
        obj.freeze if obj.respond_to?(:freeze)
      end
      obj
    end

    # Serializes internal data to a JSON-safe hash with string keys.
    #
    # Internal data uses symbol keys and Float::INFINITY for unbounded
    # max_occurs. This method converts to string keys and replaces
    # Infinity with the string "Infinity" for JSON compatibility.
    # No symbol values exist in the internal format — type and status
    # fields use strings to ensure clean round-tripping.
    #
    # @param obj [Object] the object to serialize
    # @return [Object] JSON-safe value
    def serialize(obj) # rubocop:disable Metrics/CyclomaticComplexity
      case obj
      when Hash  then obj.transform_keys(&:to_s).transform_values { |v| serialize(v) }
      when Array then obj.map { |v| serialize(v) }
      when Float then obj.infinite? ? 'Infinity' : obj
      else obj
      end
    end

    # Deserializes a JSON-parsed hash back to internal format with symbol keys.
    #
    # Only transforms hash keys (string → symbol) and the sentinel
    # string "Infinity" (→ Float::INFINITY). All other values pass
    # through unchanged — no guessing about which strings are symbols.
    #
    # @param obj [Object] the object to deserialize
    # @return [Object] internal-format value
    def self.deserialize(obj)
      case obj
      when Hash       then obj.to_h { |k, v| [k.to_sym, deserialize(v)] }
      when Array      then obj.map { |v| deserialize(v) }
      when 'Infinity' then Float::INFINITY
      else obj
      end
    end
    private_class_method :deserialize
  end
end
