# frozen_string_literal: true

require 'base64'
require 'nokogiri'

module WSDL
  class Response
    # Builds SOAP response XML from a Ruby hash using WSDL schema elements.
    #
    # This is the inverse of {Parser}: where the parser converts SOAP XML
    # into Ruby hashes, the builder converts Ruby hashes back into SOAP XML.
    # The hash structure follows the same convention as {Contract::Template#to_h},
    # with type placeholders replaced by actual values.
    #
    # The builder validates the hash against the schema during construction,
    # catching unknown elements, missing required elements, type mismatches,
    # and cardinality violations.
    #
    # @example Building a SOAP response
    #   builder = WSDL::Response::Builder.new(
    #     schema_elements: operation.contract.response.body.elements,
    #     soap_version: '1.1'
    #   )
    #
    #   xml = builder.to_xml(
    #     details: {
    #       bezeichnung: 'Deutsche Bank',
    #       bic: 'DEUTDEMM',
    #       ort: 'München',
    #       plz: '80271'
    #     }
    #   )
    #
    # @example Validating without building XML
    #   builder.validate!(details: { bezeichnung: 'Deutsche Bank' })
    #
    class Builder # rubocop:disable Metrics/ClassLength -- type-aware serialization adds essential methods
      # Maps XSD type groups to accepted Ruby classes for validation.
      #
      # @return [Hash{Symbol => Array<Class>}]
      TYPE_MAP = {
        string: [String],
        integer: [Integer],
        decimal: [Integer, Float, BigDecimal],
        float: [Integer, Float],
        boolean: [TrueClass, FalseClass],
        date: [Date, String],
        datetime: [Time, String],
        time: [Time, String],
        base64: [String],
        hex_binary: [String],
        list: [Array]
      }.freeze

      # Creates a new builder for the given output schema.
      #
      # For RPC/literal operations, pass +output_style+, +operation_name+, and
      # +output_namespace+ so the builder wraps message parts in the standard
      # +operationNameResponse+ element per SOAP 1.1 §7.1.
      #
      # @param schema_elements [Array<WSDL::XML::Element>] the output schema elements
      #   (typically from +operation.contract.response.body.elements+)
      # @param soap_version [String] SOAP version ('1.1' or '1.2')
      # @param output_style [String] binding style ('document/literal' or 'rpc/literal')
      # @param operation_name [String, nil] operation name (required for RPC/literal)
      # @param output_namespace [String, nil] soap:body namespace for the RPC wrapper
      def initialize(schema_elements:, soap_version: '1.1',
                     output_style: 'document/literal',
                     operation_name: nil, output_namespace: nil)
        @schema_elements = schema_elements
        @soap_version = soap_version
        @output_style = output_style
        @operation_name = operation_name
        @output_namespace = output_namespace
      end

      # Validates and serializes a Ruby hash into a SOAP envelope XML string.
      #
      # The hash represents the content inside the wrapper element. For example,
      # if the schema defines +getBankResponse+ as the wrapper, the hash should
      # contain the children of that element (e.g. +{ details: { ... } }+).
      #
      # @param hash [Hash] the response data
      # @return [String] the SOAP envelope XML
      # @raise [ResponseBuildError] when the hash doesn't match the schema
      def to_xml(hash)
        validate!(hash)
        serialize(hash)
      end

      # Validates a Ruby hash against the output schema without serializing.
      #
      # Useful for checking response definitions at load time.
      #
      # @param hash [Hash] the response data to validate
      # @raise [ResponseBuildError] when the hash doesn't match the schema
      # @return [void]
      def validate!(hash)
        wrapper = @schema_elements.first
        return if wrapper.nil?

        if wrapper.complex_type?
          validate_hash(hash, wrapper, path: wrapper.name)
        else
          validate_parts(hash, @schema_elements)
        end
      end

      private

      # ============================================================
      # Validation
      # ============================================================

      def validate_parts(hash, schema_elements)
        schema_by_name = schema_elements.to_h { |el| [el.name.to_sym, el] }

        hash.each_key do |key|
          next if schema_by_name.key?(key)

          raise ResponseBuildError,
            "Unknown part #{key.inspect}. Expected: #{schema_by_name.keys.inspect}"
        end

        hash.each do |key, value|
          element = schema_by_name[key] or next
          validate_type(value, element.base_type, key.to_s) if element.simple_type?
        end
      end

      def validate_hash(hash, schema_element, path:)
        attrs, elements = split_attributes(hash)
        schema_by_name = schema_element.children.to_h { |el| [el.name.to_sym, el] }

        validate_attributes(attrs, schema_element.attributes, path)
        validate_no_unknown_keys(elements, schema_by_name, path)
        validate_required_elements(schema_element.children, elements, path)
        validate_child_values(elements, schema_by_name, path)
      end

      def split_attributes(hash)
        attrs = {}
        elements = {}

        hash.each do |key, value|
          key_s = key.to_s
          if key_s.start_with?('_')
            attrs[key_s.delete_prefix('_')] = value
          else
            elements[key] = value
          end
        end

        [attrs, elements]
      end

      def validate_attributes(attrs, schema_attrs, path)
        schema_attr_names = schema_attrs.to_set(&:name)

        attrs.each_key do |name|
          next if schema_attr_names.include?(name)

          raise ResponseBuildError,
            "Unknown attribute #{name.inspect} at #{path}. " \
            "Expected: #{schema_attr_names.to_a.inspect}"
        end
      end

      def validate_no_unknown_keys(hash, schema_by_name, path)
        hash.each_key do |key|
          next if schema_by_name.key?(key)

          raise ResponseBuildError,
            "Unknown element #{key.inspect} at #{path}. " \
            "Expected: #{schema_by_name.keys.inspect}"
        end
      end

      def validate_required_elements(schema_children, hash, path)
        schema_children.each do |element|
          next if element.optional?
          next if hash.key?(element.name.to_sym)

          raise ResponseBuildError,
            "Missing required element #{element.name.inspect} at #{path}"
        end
      end

      def validate_child_values(hash, schema_by_name, path)
        hash.each do |key, value|
          element = schema_by_name[key]
          next unless element

          child_path = "#{path}/#{key}"
          validate_cardinality(value, element, child_path)

          if value.is_a?(Array)
            value.each { |item| validate_single_value(item, element, child_path) }
          else
            validate_single_value(value, element, child_path)
          end
        end
      end

      def validate_cardinality(value, element, path)
        return unless element.singular? && value.is_a?(Array)
        return if element.list?

        raise ResponseBuildError,
          "Singular element #{element.name.inspect} at #{path} received an Array. " \
          'Use a scalar value, or check that maxOccurs > 1 in the schema.'
      end

      def validate_single_value(value, element, path)
        if element.complex_type? && value.is_a?(Hash)
          validate_hash(value, element, path:)
        elsif element.simple_type?
          validate_type(value, element.base_type, path)
        end
      end

      def validate_type(value, xsd_type, path)
        return if value.nil?

        allowed = allowed_classes(xsd_type)
        return if allowed.nil?
        return if allowed.any? { |klass| value.is_a?(klass) }

        raise ResponseBuildError,
          "Type mismatch at #{path}: expected #{xsd_type} " \
          "(#{allowed.map(&:name).join('/')}) but got #{value.class.name} (#{value.inspect})"
      end

      def allowed_classes(xsd_type)
        local = xsd_type&.split(':')&.last
        group = TypeCoercer::TYPE_GROUPS[local]
        TYPE_MAP[group]
      end

      # ============================================================
      # Serialization
      # ============================================================

      def serialize(hash)
        doc = Nokogiri::XML::Document.new
        namespaces = {}
        envelope = build_soap_envelope(doc, namespaces)

        body = envelope.at_xpath('env:Body', 'env' => envelope.namespace.href)
        parent = rpc_literal? ? build_rpc_wrapper(doc, body, namespaces, envelope) : body

        @schema_elements.each do |element|
          content = element.complex_type? ? hash : hash[element.name.to_sym]
          parent.add_child(build_element(doc, element, content, namespaces, envelope))
        end

        doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML |
                                   Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
      end

      def rpc_literal?
        @output_style == 'rpc/literal'
      end

      # Builds the RPC response wrapper element per SOAP 1.1 §7.1.
      #
      # @return [Nokogiri::XML::Node] the wrapper node (already appended to body)
      def build_rpc_wrapper(doc, body, namespaces, root)
        wrapper = Nokogiri::XML::Node.new("#{@operation_name}Response", doc)

        if @output_namespace
          prefix = resolve_prefix(@output_namespace, namespaces)
          wrapper.namespace = ensure_namespace(root, prefix, @output_namespace, namespaces)
        end

        body.add_child(wrapper)
        wrapper
      end

      def build_soap_envelope(doc, namespaces)
        soap_ns = @soap_version == '1.2' ? NS::SOAP_1_2 : NS::SOAP_1_1

        envelope = build_envelope_element(doc, 'Envelope', soap_ns, 'env', namespaces)
        doc.root = envelope
        envelope.add_child(build_envelope_element(doc, 'Header', soap_ns, 'env', namespaces))
        envelope.add_child(build_envelope_element(doc, 'Body', soap_ns, 'env', namespaces))
        envelope
      end

      def build_envelope_element(doc, local_name, namespace_uri, prefix, namespaces)
        node = Nokogiri::XML::Node.new(local_name, doc)

        unless namespaces.key?(namespace_uri)
          ns = node.add_namespace_definition(prefix, namespace_uri)
          namespaces[namespace_uri] = ns
        end

        node.namespace = namespaces[namespace_uri]
        node
      end

      def build_element(doc, schema_element, content, namespaces, root)
        node = Nokogiri::XML::Node.new(schema_element.name, doc)
        apply_namespace(node, schema_element, namespaces, root)

        if content.nil? && schema_element.nillable?
          apply_xsi_nil(node, root, namespaces)
        elsif schema_element.simple_type?
          node.content = serialize_value(content, schema_element.base_type) unless content.nil?
        elsif content.is_a?(Hash)
          attrs, elements = split_attributes(content)
          apply_attributes(node, attrs, schema_element.attributes)
          build_children(node, schema_element.children, elements, doc:, namespaces:, root:)
        end

        node
      end

      def build_children(parent, schema_children, content_hash, context)
        schema_children.each do |child_element|
          child_key = child_element.name.to_sym
          next unless content_hash.key?(child_key)

          child_value = content_hash[child_key]
          items = child_value.is_a?(Array) && !child_element.list? ? child_value : [child_value]

          items.each do |item|
            child_node = build_element(
              context[:doc], child_element, item, context[:namespaces], context[:root]
            )
            parent.add_child(child_node)
          end
        end
      end

      def apply_xsi_nil(node, root, namespaces)
        ensure_namespace(root, 'xsi', NS::XSI, namespaces)
        node['xsi:nil'] = 'true'
      end

      def apply_attributes(node, attrs, schema_attrs)
        schema_by_name = schema_attrs.to_h { |a| [a.name, a] }

        attrs.each do |name, value|
          node[name] = serialize_value(value, schema_by_name[name]&.base_type)
        end
      end

      # Serializes a Ruby value to its XML text representation.
      #
      # Applies type-aware encoding for values that need it:
      # - Time objects with xs:time type produce time-only strings (e.g. '14:30:00Z')
      # - Time objects with xs:dateTime or nil type produce full ISO 8601 strings
      # - base64Binary values are Base64-encoded
      # - hexBinary values are hex-encoded
      #
      # @param value [Object] the value to serialize
      # @param xsd_type [String, nil] the XSD type name (e.g. 'xsd:dateTime', 'xsd:time')
      # @return [String] the XML text representation
      def serialize_value(value, xsd_type = nil)
        return serialize_time(value, xsd_type) if value.is_a?(Time)
        return value.join(' ') if value.is_a?(Array)

        type_local = xsd_type&.split(':')&.last
        case type_local
        when 'base64Binary' then Base64.strict_encode64(value.to_s)
        when 'hexBinary' then value.to_s.unpack1('H*')
        else value.to_s
        end
      end

      # Serializes a Time value based on the XSD type.
      #
      # Preserves fractional seconds when present, using up to microsecond
      # precision (6 digits). Trailing fractional zeros are stripped to
      # produce canonical output per XSD Part 2 Section 3.2.7.2.
      # Sub-microsecond values below the 6-digit precision threshold are
      # treated as whole seconds (e.g. 100ns becomes '14:30:00Z', not '14:30:00.0Z').
      #
      # For xs:time, strips the date portion from the xmlschema output,
      # producing a time-only string (e.g. '14:30:00.5Z'). For xs:dateTime
      # or when no type is specified, returns the full ISO 8601 string.
      #
      # @param value [Time] the time value to serialize
      # @param xsd_type [String, nil] the XSD type name
      # @return [String] the serialized time string
      # @api private
      def serialize_time(value, xsd_type)
        fraction = value.subsec.zero? ? 0 : 6
        iso = value.xmlschema(fraction)
        iso = iso.sub(/(\.\d+?)0+(Z|[+-])/, '\1\2') if fraction.positive?
        iso = iso.sub(/\.0(Z|[+-])/, '\1') if fraction.positive?
        return iso unless xsd_type&.end_with?(':time')

        iso.sub(/\A\d{4}-\d{2}-\d{2}T/, '')
      end

      def apply_namespace(node, schema_element, namespaces, root)
        return unless schema_element.namespace && schema_element.form != 'unqualified'

        prefix = resolve_prefix(schema_element.namespace, namespaces)
        node.namespace = ensure_namespace(root, prefix, schema_element.namespace, namespaces)
      end

      def resolve_prefix(uri, namespaces)
        return namespaces[uri].prefix if namespaces.key?(uri)

        "ns#{namespaces.size}"
      end

      def ensure_namespace(root, prefix, uri, namespaces)
        return namespaces[uri] if namespaces.key?(uri)

        ns = root.add_namespace_definition(prefix, uri)
        namespaces[uri] = ns
        ns
      end
    end
  end
end
