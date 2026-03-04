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

    # rubocop:disable Metrics/ParameterLists
    def initialize(operation_info, parser_result, http, pretty_print: true, strict_schema: true, request_limits: {})
      # rubocop:enable Metrics/ParameterLists
      @operation_info = operation_info
      @parser_result = parser_result
      @http = http
      @pretty_print = pretty_print
      @strict_schema = strict_schema
      @request_limits = request_limits

      @endpoint = operation_info.endpoint
      @soap_version = operation_info.soap_version
      @soap_action = operation_info.soap_action
      @encoding = ENCODING

      @request_document = nil
      @security = Security::Config.new
    end

    attr_accessor :endpoint, :soap_version, :soap_action, :encoding, :pretty_print

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

      document = Request::Document.new
      security = Security::Config.new
      context = Request::DSLContext.new(document:, security:, request_limits: @request_limits)
      context.instance_exec(&block)

      validation_contract = request_validation_contract

      Request::Validator.new(
        contract: validation_contract,
        strict_schema: @strict_schema,
        schema_complete: schema_complete_for_validation?
      ).validate!(document)

      Request::SecurityConflictDetector.new(document:, security:).validate!

      @request_document = document
      @security = security
      self
    end

    # Returns HTTP headers for the current SOAP version/action.
    #
    # @return [Hash{String => String}]
    def http_headers
      return @custom_http_headers unless @custom_http_headers.nil?

      headers = {}
      content_type = [CONTENT_TYPE[soap_version], "charset=#{encoding}"]

      case soap_version
      when '1.1'
        headers['SOAPAction'] = soap_action.nil? ? '' : %("#{soap_action}")
      when '1.2'
        content_type << %(action="#{soap_action}") if soap_action && !soap_action.empty?
      end

      headers['Content-Type'] = content_type.join(';')
      headers
    end

    # Overrides auto-generated HTTP headers for outbound calls.
    #
    # @param headers [Hash{String => String}]
    # @return [void]
    def http_headers=(headers)
      @custom_http_headers = headers
    end

    # Serializes the prepared request AST to SOAP envelope XML.
    #
    # @return [String]
    def to_xml
      ensure_request_definition!

      document = build_serializable_document(@request_document || Request::Document.new)
      xml = Request::Serializer.new(document:, soap_version:, pretty_print:).serialize
      return xml unless @security.configured?

      Security::SecurityHeader.new(@security).apply(xml)
    end

    # Invokes this SOAP operation.
    #
    # @return [Response]
    def invoke
      ensure_request_definition!

      raw_response = @http.post(endpoint, http_headers, to_xml)
      response = Response.new(
        raw_response,
        output_body_parts: @operation_info.output.body_parts,
        output_header_parts: @operation_info.output.header_parts,
        verification: @security.response_verification_options
      )

      enforce_response_verification!(response)
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

    def build_serializable_document(document)
      return document unless needs_rpc_wrapping?(document)

      wrap_rpc_document(document)
    end

    def needs_rpc_wrapping?(document)
      rpc_literal? && !document.body.empty? && !already_rpc_wrapped?(document.body)
    end

    def wrap_rpc_document(document)
      wrapped = Request::Document.new
      wrapped.namespace_decls.concat(document.namespace_decls)
      wrapped.header.concat(document.header)
      wrapped.body << build_rpc_wrapper(document.body)
      wrapped
    end

    def build_rpc_wrapper(children)
      wrapper = Request::Node.new(
        name: @operation_info.name,
        prefix: nil,
        local_name: @operation_info.name,
        namespace_uri: @operation_info.binding_operation.input_body[:namespace]
      )
      wrapper.children.concat(children)
      wrapper
    end

    def rpc_literal?
      input_style == 'rpc/literal'
    end

    def already_rpc_wrapped?(body_nodes)
      body_nodes.length == 1 && body_nodes.first.local_name == @operation_info.name
    end

    def ensure_request_definition!
      return if @request_document
      return if contract.request.empty?

      raise RequestDefinitionError,
            "Operation #{@operation_info.name.inspect} requires a request definition via operation.prepare { ... }"
    end

    def request_validation_contract
      contract
    rescue UnresolvedReferenceError
      raise if @strict_schema

      fallback_validation_contract
    end

    def schema_complete_for_validation?
      return true unless @strict_schema

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

    def enforce_response_verification!(response)
      case @security.verification_mode
      when Security::ResponsePolicy::MODE_DISABLED
        nil
      when Security::ResponsePolicy::MODE_IF_PRESENT
        response.security.verify! if response.security.signature_present?
      when Security::ResponsePolicy::MODE_REQUIRED
        response.security.verify!
      else
        raise ArgumentError, "Unknown response verification mode: #{@security.verification_mode.inspect}"
      end
    end
  end
end
