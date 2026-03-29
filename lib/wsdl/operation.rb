# frozen_string_literal: true

module WSDL
  # Represents a callable SOAP operation.
  #
  # Operation instances carry mutable per-request state ({#prepare}, {#reset!},
  # {#invoke}) and are therefore **not thread-safe**. Create a separate
  # Operation per thread or per request. The underlying {Definition} is
  # frozen and safe to share.
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

    # Creates a new Operation from Definition operation data.
    #
    # All read-only derived fields (contract, element parts, RPC wrapper)
    # are eagerly computed from the frozen +op_data+ during construction
    # so they are safe for concurrent reads without synchronization.
    #
    # @param op_data [Hash{Symbol => Object}] operation hash from {Definition#operation_data}
    # @param endpoint [String] the SOAP endpoint URL
    # @param http [Object] an HTTP client instance
    # @param config [Config] behavioral configuration
    def initialize(op_data, endpoint, http, config: Config.new)
      @op_data = op_data
      @http = http
      @config = config

      @endpoint = endpoint
      @soap_version = op_data[:soap_version]
      @soap_action = op_data[:soap_action]
      @encoding = ENCODING

      @request_document = nil
      @security = Security::Config.new
      @http_header_overrides = {}

      build_derived_fields(op_data)
    end

    # Returns the operation name from the WSDL definition.
    #
    # @return [String]
    #
    # @example
    #   operation.name  # => "getBank"
    #
    def name
      @op_data[:name]
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
      input_body_parts.first&.name
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
      @op_data[:rpc_output_namespace]
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

    # Returns canonical operation contract metadata.
    #
    # @return [WSDL::Contract::OperationContract]
    attr_reader :contract

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

      Request::Validator.new(
        contract:,
        strictness: @config.strictness,
        schema_complete: @op_data[:schema_complete]
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
    # Also clears any custom HTTP header overrides set via {#http_headers=}.
    #
    # @return [self]
    def reset!
      @request_document = nil
      @security = Security::Config.new
      @http_header_overrides = {}
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
    # By default, returns compact XML (no extra whitespace). Pass
    # +pretty: true+ to get indented output for debugging or logging.
    #
    # @param pretty [Boolean] format XML with indentation (default: false)
    # @return [String]
    #
    # @example Compact XML (default)
    #   operation.to_xml
    #
    # @example Pretty-printed for inspection
    #   puts operation.to_xml(pretty: true)
    #
    def to_xml(pretty: false)
      ensure_request_definition!

      document = prepare_serializable_document(@request_document || Request::Envelope.new)
      serializer = Request::Serializer.new(document:, soap_version:, pretty:)
      return serializer.serialize unless @security.configured?

      Security::SecurityHeader.new(@security).apply(serializer.to_document)
    end

    # Invokes this SOAP operation.
    #
    # When a block is given, calls {#prepare} first — combining
    # request building and invocation into a single step.
    #
    # @yield optional request DSL block (forwarded to {#prepare})
    # @return [Response]
    # @raise [ResourceLimitError] when the response body exceeds {Limits#max_response_size}
    #
    # @example One-step invoke
    #   response = operation.invoke do
    #     tag('GetUser') { tag('id', 123) }
    #   end
    #
    def invoke(&block)
      prepare(&block) if block
      ensure_request_definition!

      http_response = @http.post(endpoint, http_headers, to_xml)
      enforce_response_size_limit!(http_response)

      response = Response.new(
        http_response:,
        output_body_parts:,
        output_header_parts:,
        output_style:,
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
      @op_data[:input_style]
    end

    # Low-level output binding style from the WSDL.
    #
    # Prefer {#contract} `.style` for public introspection.
    #
    # @api private
    # @return [String] e.g. `document/literal`
    def output_style
      @op_data[:output_style]
    end

    private

    # @return [Array<Definition::Element>] input header part elements
    attr_reader :input_header_parts

    # @return [Array<Definition::Element>] input body part elements
    attr_reader :input_body_parts

    # @return [Array<Definition::Element>, nil] output header part elements
    attr_reader :output_header_parts

    # @return [Array<Definition::Element>, nil] output body part elements
    attr_reader :output_body_parts

    # @return [Array<Definition::Element>] wrapped element hashes
    def wrap_elements(hashes)
      return [] unless hashes

      hashes.map { |h| Definition::Element.new(h) }.freeze
    end

    def enforce_response_size_limit!(http_response)
      max = @config.limits.max_response_size
      return unless max

      actual = http_response.body.bytesize
      return unless actual > max

      raise ResourceLimitError.new(
        "Response size #{Formatting.format_bytes(actual)} exceeds limit of #{Formatting.format_bytes(max)}" \
        "\nTo increase, use: limits: { max_response_size: #{actual} }",
        limit_name: :max_response_size,
        limit_value: max,
        actual_value: actual
      )
    end

    def prepare_serializable_document(document)
      return document unless @rpc_wrapper

      @rpc_wrapper.wrap(document)
    end

    def rpc_literal?
      input_style == 'rpc/literal'
    end

    def ensure_request_definition!
      return if @request_document
      return if contract.request.empty?

      raise RequestDefinitionError,
        "Operation #{name.inspect} requires a request definition via operation.prepare { ... }"
    end

    # Eagerly computes all read-only derived fields from frozen op_data.
    #
    # Called once during {#initialize} so these fields are safe for
    # concurrent reads without synchronization.
    #
    # @param op_data [Hash{Symbol => Object}] operation hash
    # @return [void]
    def build_derived_fields(op_data)
      @input_header_parts = wrap_elements(op_data.dig(:input, :header))
      @input_body_parts = wrap_elements(op_data.dig(:input, :body))
      @output_header_parts = op_data[:output] ? wrap_elements(op_data[:output][:header]) : nil
      @output_body_parts = op_data[:output] ? wrap_elements(op_data[:output][:body]) : nil
      @contract = build_contract
      @rpc_wrapper = rpc_literal? ? build_rpc_wrapper : nil
    end

    # Builds the frozen {Contract::OperationContract} from pre-computed parts.
    #
    # @return [Contract::OperationContract]
    def build_contract
      Contract::OperationContract.new(
        input_header_parts: @input_header_parts,
        input_body_parts: @input_body_parts,
        output_header_parts: @output_header_parts || [],
        output_body_parts: @output_body_parts || [],
        input_style:
      )
    end

    # Builds the {Request::RPCWrapper} for RPC/literal operations.
    #
    # @return [Request::RPCWrapper]
    def build_rpc_wrapper
      Request::RPCWrapper.new(
        operation_name: name,
        namespace_uri: @op_data[:rpc_input_namespace]
      )
    end
  end
end
