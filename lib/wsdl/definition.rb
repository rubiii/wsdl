# frozen_string_literal: true

require 'json'
require 'wsdl/definition/element_hash'
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
  class Definition # rubocop:disable Metrics/ClassLength
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

    # Returns build issues encountered during Definition construction.
    #
    # Each entry records an operation that could not be fully resolved
    # and the reason. These operations are included in the Definition
    # with empty message parts.
    #
    # @return [Array<Hash{Symbol => String}>] build issue entries with
    #   +:operation+ and +:error+ keys
    #
    # @example
    #   definition.build_issues
    #   # => [{ operation: "GetStatus", error: "Unable to find element ..." }]
    def build_issues
      @data[:build_issues] || []
    end

    # Raises if any build issues were recorded during construction.
    #
    # Call this after {WSDL.parse} if you want strict behavior — failing
    # on any operation that could not be fully resolved.
    #
    # @return [self] if no issues
    # @raise [DefinitionError] if there are build issues
    #
    # @example Strict parsing
    #   definition = WSDL.parse(url)
    #   definition.verify!  # raises if any operations couldn't be fully built
    #
    def verify!
      raise DefinitionError, build_issues if build_issues.any?

      self
    end

    # Returns all services. Arguments filter the results.
    #
    # @return [Array<Hash>] service entries with +:name+ and +:ports+ keys
    #
    # @example
    #   definition.services
    #   # => [{ name: "UserService", ports: ["UserPort", "AdminPort"] }]
    def services
      @data[:services].map do |name, data|
        { name:, ports: data[:ports].keys }
      end
    end

    # Returns all ports. Pass a service name to filter.
    #
    # @param service_name [String, nil] optional service name filter
    # @return [Array<Hash>] port entries with +:service+, +:name+, +:endpoint+ keys
    #
    # @example
    #   definition.ports("UserService")
    #   # => [{ service: "UserService", name: "UserPort", endpoint: "http://..." }]
    def ports(service_name = nil)
      each_port(service_name).map do |svc_name, port_name, port_data|
        { service: svc_name, name: port_name, endpoint: port_data[:endpoint] }
      end
    end

    # Returns all operations. Pass service and port names to filter.
    #
    # @param service_name [String, nil] optional service name filter
    # @param port_name [String, nil] optional port name filter
    # @return [Array<Hash>] operation entries with consistent keys
    #
    # @example
    #   definition.operations("UserService", "UserPort")
    #   # => [{ service: "UserService", port: "UserPort", name: "GetUser",
    #   #       style: "document/literal", soap_action: "..." }]
    def operations(service_name = nil, port_name = nil)
      result = []
      each_operation(service_name, port_name) do |svc, port, op|
        entry = {
          service: svc, port:, name: op[:name],
          style: op[:input_style], soap_action: op[:soap_action]
        }
        entry[:input_name] = op[:input_name] if op[:input_name]
        result << entry
      end
      result
    end

    # Returns a developer-friendly view of an operation's input body.
    #
    # Auto-resolves service and port for single-service/port WSDLs.
    # For multiple services/ports, pass them explicitly.
    #
    # @overload input(operation_name)
    # @overload input(service_name, port_name, operation_name)
    # @return [Array<Hash>] element structure with human-readable types
    def input(*)
      op = resolve_operation(*)
      op[:input][:body].map { |el| project_element(el) }
    end

    # Returns a developer-friendly view of an operation's input headers.
    #
    # @overload input_header(operation_name)
    # @overload input_header(service_name, port_name, operation_name)
    # @return [Array<Hash>] header element structure
    def input_header(*)
      op = resolve_operation(*)
      op[:input][:header].map { |el| project_element(el) }
    end

    # Returns a developer-friendly view of an operation's output body.
    #
    # @overload output(operation_name)
    # @overload output(service_name, port_name, operation_name)
    # @return [Array<Hash>] element structure with human-readable types
    def output(*)
      op = resolve_operation(*)
      return [] unless op[:output]

      op[:output][:body].map { |el| project_element(el) }
    end

    # Returns a developer-friendly view of an operation's output headers.
    #
    # @overload output_header(operation_name)
    # @overload output_header(service_name, port_name, operation_name)
    # @return [Array<Hash>] header element structure
    def output_header(*)
      op = resolve_operation(*)
      return [] unless op[:output]

      op[:output][:header].map { |el| project_element(el) }
    end

    # Returns the full internal operation data for use by Client/Operation.
    #
    # @overload operation_data(operation_name)
    # @overload operation_data(service_name, port_name, operation_name)
    # @param input_name [String, nil] disambiguator for overloaded operations
    # @return [Hash] internal operation hash with full element data
    # @api private
    def operation_data(*, input_name: nil)
      resolve_operation(*, input_name:)
    end

    # Returns a pasteable DSL snippet for building a request.
    #
    # Generates code for both header and body sections that can be
    # copy-pasted into an +invoke+ or +prepare+ block.
    #
    # @overload to_dsl(operation_name)
    # @overload to_dsl(service_name, port_name, operation_name)
    # @return [String] Ruby DSL code snippet
    #
    # @example
    #   definition.to_dsl("GetUser")
    #   # => "body do\n  tag('GetUser') do\n    tag('id', 'integer')\n  end\nend"
    def to_dsl(*)
      op = resolve_operation(*)
      lines = []
      append_dsl_section(lines, 'header', op[:input][:header])
      append_dsl_section(lines, 'body', op[:input][:body])
      lines.join("\n")
    end

    # Returns the endpoint URL for a specific service and port.
    #
    # @param service_name [String] the service name
    # @param port_name [String] the port name
    # @return [String] the endpoint URL
    # @api private
    def endpoint(service_name, port_name)
      @data[:services][service_name][:ports][port_name][:endpoint]
    end

    # Returns the SOAP type namespace URI for a port.
    #
    # @param service_name [String] the service name
    # @param port_name [String] the port name
    # @return [String] the SOAP namespace URI
    # @api private
    def port_type(service_name, port_name)
      @data[:services][service_name][:ports][port_name][:type]
    end

    # Resolves the single service and port for auto-resolution.
    #
    # @return [Array(String, String)] service and port names
    # @raise [ArgumentError] if ambiguous
    # @api private
    # rubocop:disable Metrics/AbcSize -- validation requires multiple checks
    def resolve_service_and_port
      svcs = @data[:services]
      if svcs.size != 1
        names = svcs.keys.map(&:inspect).join(', ')
        raise ArgumentError, "Cannot auto-resolve service: expected 1, found #{svcs.size} (#{names}). " \
                             'Pass explicit service and port names.'
      end

      svc_name = svcs.keys.first
      ports = svcs[svc_name][:ports]
      if ports.size != 1
        names = ports.keys.map(&:inspect).join(', ')
        raise ArgumentError, "Cannot auto-resolve port for service #{svc_name.inspect}: " \
                             "expected 1, found #{ports.size} (#{names}). " \
                             'Pass explicit service and port names.'
      end

      [svc_name, ports.keys.first]
    end
    # rubocop:enable Metrics/AbcSize

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

    # Resolves an operation by name, with optional service/port scoping.
    #
    # @param args [Array] (operation_name) or (service, port, operation_name)
    # @param input_name [String, nil] disambiguator for overloaded operations
    # @return [Hash] internal operation data
    # @raise [ArgumentError] if operation not found or ambiguous
    def resolve_operation(*args, input_name: nil)
      case args.size
      when 1 then resolve_auto_operation(args[0], input_name:)
      when 3 then resolve_explicit_operation(args[0], args[1], args[2], input_name:)
      else
        raise ArgumentError,
          'Pass 1 argument (operation_name) or 3 arguments (service_name, port_name, operation_name).'
      end
    end

    # Resolves an operation by name with auto-resolution of service/port.
    #
    # @param operation_name [String] the operation name
    # @param input_name [String, nil] disambiguator
    # @return [Hash] operation data
    def resolve_auto_operation(operation_name, input_name: nil)
      svc_name, port_name = resolve_service_and_port
      resolve_explicit_operation(svc_name, port_name, operation_name, input_name:)
    end

    # Resolves an operation with explicit service, port, and operation names.
    #
    # @param svc [String] service name
    # @param port [String] port name
    # @param operation [String] operation name
    # @param input_name [String, nil] disambiguator
    # @return [Hash] operation data
    # @raise [ArgumentError] if not found
    def resolve_explicit_operation(svc, port, operation, input_name: nil)
      ops = @data.dig(:services, svc, :ports, port, :operations)
      raise ArgumentError, unknown_operation_message(svc, port, operation) unless ops&.key?(operation)

      entry = ops[operation]
      return disambiguate_overload(entry, operation, input_name) if entry.is_a?(Array)

      entry
    end

    # Disambiguates an overloaded operation by input_name.
    #
    # @param entries [Array<Hash>] overloaded operation entries
    # @param operation [String] operation name
    # @param input_name [String, nil] disambiguator
    # @return [Hash] matched operation data
    # @raise [ArgumentError] if ambiguous
    def disambiguate_overload(entries, operation, input_name)
      unless input_name
        available = entries.filter_map { |e| e[:input_name] }
        raise ArgumentError,
          "Operation #{operation.inspect} is overloaded. Pass input_name: to disambiguate. " \
          "Available: #{available.inspect}"
      end

      match = entries.find { |e| e[:input_name] == input_name }
      return match if match

      available = entries.filter_map { |e| e[:input_name] }
      raise ArgumentError,
        "No overload of #{operation.inspect} matches input_name: #{input_name.inspect}. " \
        "Available: #{available.inspect}"
    end

    # @return [String] error message for unknown operations
    def unknown_operation_message(service, port, operation)
      ops = @data.dig(:services, service, :ports, port, :operations)
      if ops
        "Unknown operation #{operation.inspect} for " \
          "service #{service.inspect} and port #{port.inspect}.\n" \
          "You may want to try one of #{ops.keys.inspect}."
      else
        "Unknown service #{service.inspect} or port #{port.inspect}."
      end
    end

    # Iterates over ports, optionally filtered by service.
    #
    # @param service_name [String, nil] optional filter
    # @yield [svc_name, port_name, port_data]
    # @return [Array]
    def each_port(service_name = nil)
      result = []
      @data[:services].each do |svc_name, svc_data|
        next if service_name && svc_name != service_name

        svc_data[:ports].each do |port_name, port_data|
          result << [svc_name, port_name, port_data]
        end
      end
      result
    end

    # Iterates over operations, optionally filtered by service and port.
    #
    # @param service_name [String, nil] optional service filter
    # @param port_name [String, nil] optional port filter
    # @yield [svc_name, port_name, op_data]
    def each_operation(service_name = nil, port_name = nil)
      each_port(service_name).each do |svc_name, p_name, port_data|
        next if port_name && p_name != port_name

        port_data[:operations].each_value do |op_or_ops|
          ops = op_or_ops.is_a?(Array) ? op_or_ops : [op_or_ops]
          ops.each { |op| yield svc_name, p_name, op }
        end
      end
    end

    # Projects an internal element hash to a developer-friendly format.
    #
    # Strips internal fields (namespace, form, xsd_type, etc.) and
    # presents human-readable types and boolean flags.
    #
    # @param element [Hash] internal element hash
    # @return [Hash] clean projection
    def project_element(element)
      result = { name: element[:name], type: project_type(element), required: element[:min_occurs].positive? }
      result[:array] = true unless element[:singular]
      result[:nillable] = true if element[:nillable]
      result[:children] = element[:children].map { |c| project_element(c) } if element[:children]&.any?
      result
    end

    # Converts an internal type to a human-readable string or symbol.
    #
    # @param element [Hash] internal element hash
    # @return [String, Symbol] human-readable type
    def project_type(element)
      case element[:type]
      when 'simple' then humanize_xsd_type(element[:xsd_type])
      else element[:type]
      end
    end

    # Strips the XSD namespace prefix from a type name.
    #
    # @param xsd_type [String, nil] e.g. "xsd:string"
    # @return [String] e.g. "string"
    def humanize_xsd_type(xsd_type)
      return xsd_type unless xsd_type

      xsd_type.sub(/\A\w+:/, '')
    end

    # Appends a DSL section (header or body) to the lines array.
    #
    # @param lines [Array<String>] accumulator
    # @param section [String] 'header' or 'body'
    # @param elements [Array<Hash>] element hashes
    # @return [void]
    def append_dsl_section(lines, section, elements)
      return if elements.empty?

      lines << "#{section} do"
      elements.each do |el|
        append_dsl_element(lines, el, indent: 2)
      end
      lines << 'end'
    end

    # Appends a single element's DSL representation.
    #
    # @param lines [Array<String>] accumulator
    # @param element [Hash] element hash
    # @param indent [Integer] indentation level
    # @return [void]
    def append_dsl_element(lines, element, indent:)
      prefix = ' ' * indent

      if element[:type] == 'simple'
        lines << "#{prefix}tag('#{element[:name]}', '#{humanize_xsd_type(element[:xsd_type])}')"
      else
        lines << "#{prefix}tag('#{element[:name]}') do"
        element[:children]&.each do |child|
          append_dsl_element(lines, child, indent: indent + 2)
        end
        lines << "#{prefix}end"
      end
    end

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
