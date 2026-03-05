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

    attr_accessor :endpoint, :soap_version, :soap_action, :encoding

    # Returns whether XML output is formatted with indentation.
    #
    # @return [Boolean]
    def format_xml
      defined?(@format_xml) ? @format_xml : @config.format_xml
    end

    # Sets whether XML output is formatted with indentation.
    #
    # @param value [Boolean]
    attr_writer :format_xml

    # Returns canonical operation contract metadata.
    #
    # @return [WSDL::Contract::OperationContract]
    def contract
      @contract ||= Contract::OperationContract.new(@operation_info)
    end

    # Prepares request AST from DSL and validates it immediately.
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

      document = Request::AST.new
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

    # Serializes the prepared request AST to SOAP envelope XML.
    #
    # @return [String]
    def to_xml
      ensure_request_definition!

      document = prepare_serializable_document(@request_document || Request::AST.new)
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
        http: http_response,
        output_body_parts: @operation_info.output.body_parts,
        output_header_parts: @operation_info.output.header_parts,
        verification: @security.response_verification_options
      )

      @security.response_policy.enforce!(response)
      response
    end

    # @return [String] e.g. `document/literal`
    def input_style
      @operation_info.input_style
    end

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
