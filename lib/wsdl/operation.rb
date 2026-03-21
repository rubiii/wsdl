# frozen_string_literal: true

module WSDL
  # Represents a callable SOAP operation.
  class Operation
    # Default XML encoding used in SOAP request headers.
    #
    # @return [String]
    ENCODING = 'UTF-8'

    # HTTP Content-Type base values keyed by SOAP version.
    #
    # @return [Hash{String => String}]
    CONTENT_TYPE = {
      '1.1' => 'text/xml',
      '1.2' => 'application/soap+xml'
    }.freeze

    def initialize(operation_info, parser_result, http, config: Config.new)
      @operation_info = operation_info
      @parser_result = parser_result
      @http = http
      @config = config

      @endpoint = operation_info.endpoint
      @soap_version = operation_info.soap_version
      @soap_action = operation_info.soap_action
      @encoding = ENCODING

      @request_document = nil
      @security = Security::Config.new
      @http_header_overrides = {}
    end

    # Returns the operation name from the WSDL definition.
    #
    # @return [String]
    #
    # @example
    #   operation.name  # => "getBank"
    #
    def name
      @operation_info.name
    end

    attr_reader :endpoint, :soap_version, :soap_action, :encoding

    # Returns the name of the first input body element.
    #
    # For document/literal wrapped operations, this is the element name
    # that appears in the SOAP body (which may differ from the operation name).
    #
    # @return [String, nil]
    #
    # @example
    #   operation.input_element_name  # => "InitialRequest"
    #
    def input_element_name
      @operation_info.input.body_parts.first&.name
    end

    # Returns the output body namespace from the WSDL binding.
    #
    # For RPC/literal operations, this is the namespace used on the
    # response wrapper element. For document/literal operations this
    # may be nil.
    #
    # @return [String, nil]
    #
    # @example
    #   operation.output_namespace  # => "http://apiNamespace.com"
    #
    def output_namespace
      @operation_info.binding_operation.output_body[:namespace]
    end

    # Overrides the SOAP endpoint URL for this operation.
    #
    # @param value [String] a non-empty endpoint URL
    # @raise [ArgumentError] when the value is not a non-empty String
    # @return [String]
    def endpoint=(value)
      raise ArgumentError, 'endpoint must be a non-empty String' unless value.is_a?(String) && !value.empty?

      @endpoint = value
    end

    # Overrides the SOAP version for this operation.
    #
    # @param value [String] `"1.1"` or `"1.2"`
    # @raise [ArgumentError] when the value is not a supported SOAP version
    # @return [String]
    def soap_version=(value)
      raise ArgumentError, "soap_version must be '1.1' or '1.2'" unless CONTENT_TYPE.key?(value)

      @soap_version = value
    end

    # Overrides the SOAP action for this operation.
    #
    # @param value [String, nil] the SOAP action string, or nil to clear
    # @raise [ArgumentError] when the value is not a String or nil
    # @return [String, nil]
    def soap_action=(value)
      raise ArgumentError, 'soap_action must be a String or nil' unless value.nil? || value.is_a?(String)

      @soap_action = value
    end

    # Overrides the XML encoding for this operation.
    #
    # @param value [String] a non-empty encoding name (e.g. `"UTF-8"`)
    # @raise [ArgumentError] when the value is not a non-empty String
    # @return [String]
    def encoding=(value)
      raise ArgumentError, 'encoding must be a non-empty String' unless value.is_a?(String) && !value.empty?

      @encoding = value
    end

    # Returns whether XML output is formatted with indentation.
    #
    # Defaults to the client's {Config#format_xml} setting. Set per-operation
    # via {#format_xml=} to override the client default for this operation only.
    #
    # @return [Boolean]
    #
    # @example Check the current setting
    #   operation.format_xml  # => true (inherits from client config)
    #
    # @example Override per-operation
    #   operation.format_xml = false
    #   operation.format_xml  # => false
    #
    def format_xml
      defined?(@format_xml) ? @format_xml : @config.format_xml
    end

    # Sets whether XML output is formatted with indentation for this operation.
    #
    # Overrides the client-level {Config#format_xml} setting for this
    # operation only. Cleared by {#reset!}.
    #
    # @param value [Boolean]
    attr_writer :format_xml

    # Returns canonical operation contract metadata.
    #
    # @return [WSDL::Contract::OperationContract]
    def contract
      @contract ||= Contract::OperationContract.new(@operation_info)
    end

    # Prepares request envelope from DSL and validates it immediately.
    #
    # @yield DSL prepare block
    # @return [self]
    def prepare(&block)
      raise RequestDslError, 'operation.prepare requires a block' unless block

      if @request_document
        raise RequestDslError,
              'operation.prepare was already called. ' \
              'Use operation.reset! to clear the previous request before preparing a new one'
      end

      document = Request::Envelope.new
      security = Security::Config.new
      context = Request::DSLContext.new(document:, security:, limits: @config.limits)
      context.instance_exec(&block)

      validation_contract = request_validation_contract

      Request::Validator.new(
        contract: validation_contract,
        strict_schema: @config.strict_schema,
        schema_complete: schema_complete_for_validation?
      ).validate!(document)

      Request::SecurityConflictDetector.new(document:, security:).validate!

      @request_document = document
      @security = security
      self
    end

    # Returns whether a request has been prepared via {#prepare}.
    #
    # @return [Boolean]
    def prepared?
      !@request_document.nil?
    end

    # Clears the prepared request, allowing {#prepare} to be called again.
    # Also clears any custom HTTP header overrides set via {#http_headers=}
    # and the per-operation {#format_xml} override.
    #
    # @return [self]
    def reset!
      @request_document = nil
      @security = Security::Config.new
      @http_header_overrides = {}
      remove_instance_variable(:@format_xml) if defined?(@format_xml)
      self
    end

    # Returns the merged HTTP headers for the SOAP request.
    #
    # Auto-generated headers (Content-Type, SOAPAction) are computed from the
    # current SOAP version, action, and encoding. Any headers set via
    # {#http_headers=} are merged on top, so user-provided values win on
    # conflict while auto-generated defaults are preserved.
    #
    # @return [Hash{String => String}]
    def http_headers
      headers = {}
      content_type = [CONTENT_TYPE[soap_version], "charset=#{encoding}"]

      case soap_version
      when '1.1'
        headers['SOAPAction'] = soap_action.nil? ? '' : %("#{soap_action}")
      when '1.2'
        content_type << %(action="#{soap_action}") if soap_action && !soap_action.empty?
      end

      headers['Content-Type'] = content_type.join(';')
      headers.merge(@http_header_overrides)
    end

    # Merges custom headers on top of auto-generated HTTP headers.
    #
    # The provided headers are stored and merged over the auto-generated
    # defaults each time {#http_headers} is called. User-provided values
    # win on conflict. Call {#reset!} to clear overrides.
    #
    # @param headers [Hash{String => String}]
    # @return [void]
    def http_headers=(headers)
      @http_header_overrides = headers
    end

    # Serializes the prepared request envelope to SOAP envelope XML.
    #
    # @return [String]
    def to_xml
      ensure_request_definition!

      document = prepare_serializable_document(@request_document || Request::Envelope.new)
      serializer = Request::Serializer.new(document:, soap_version:, format_xml:)
      return serializer.serialize unless @security.configured?

      Security::SecurityHeader.new(@security).apply(serializer.to_document)
    end

    # Invokes this SOAP operation.
    #
    # @return [Response]
    # @raise [ResourceLimitError] when the response body exceeds {Limits#max_response_size}
    def invoke
      ensure_request_definition!

      http_response = @http.post(endpoint, http_headers, to_xml)
      enforce_response_size_limit!(http_response)

      response = Response.new(
        http_response:,
        output_body_parts: @operation_info.output.body_parts,
        output_header_parts: @operation_info.output.header_parts,
        verification: @security.response_verification_options
      )

      @security.response_policy.enforce!(response)
      response
    end

    # Low-level input binding style from the WSDL.
    #
    # Prefer {#contract} `.style` for public introspection.
    #
    # @api private
    # @return [String] e.g. `document/literal`
    def input_style
      @operation_info.input_style
    end

    # Low-level output binding style from the WSDL.
    #
    # Prefer {#contract} `.style` for public introspection.
    #
    # @api private
    # @return [String] e.g. `document/literal`
    def output_style
      @operation_info.output_style
    end

    private

    def enforce_response_size_limit!(http_response)
      max = @config.limits.max_response_size
      return unless max

      actual = http_response.body.bytesize
      return unless actual > max

      raise ResourceLimitError.new(
        "Response size #{Formatting.format_bytes(actual)} exceeds limit of #{Formatting.format_bytes(max)}",
        limit_name: :max_response_size,
        limit_value: max,
        actual_value: actual
      )
    end

    def prepare_serializable_document(document)
      return document unless rpc_literal?

      rpc_wrapper.wrap(document)
    end

    def rpc_wrapper
      @rpc_wrapper ||= Request::RPCWrapper.new(
        operation_name: @operation_info.name,
        namespace_uri: @operation_info.binding_operation.input_body[:namespace]
      )
    end

    def rpc_literal?
      input_style == 'rpc/literal'
    end

    def ensure_request_definition!
      return if @request_document
      return if contract.request.empty?

      raise RequestDefinitionError,
            "Operation #{@operation_info.name.inspect} requires a request definition via operation.prepare { ... }"
    end

    def request_validation_contract
      contract
    rescue UnresolvedReferenceError => e
      raise if @config.strict_schema
      raise unless schema_unresolved_reference?(e)

      fallback_validation_contract
    end

    def schema_complete_for_validation?
      return true unless @config.strict_schema

      @parser_result.schema_complete_for_operation?(@operation_info)
    end

    def fallback_validation_contract
      @fallback_validation_contract ||= begin
        header = Contract::PartContract.new([], section: :header)
        body = Contract::PartContract.new([], section: :body)
        request = Contract::MessageContract.new(header:, body:)
        validation_contract_type.new(request:, style: input_style)
      end
    end

    def validation_contract_type
      @validation_contract_type ||= Data.define(:request, :style)
    end

    def schema_unresolved_reference?(error)
      schema_reference_types = %i[
        schema_namespace
        type
        simple_type
        complex_type
        element
        attribute
        attribute_group
      ]
      schema_reference_types.include?(error.reference_type)
    end
  end
end
