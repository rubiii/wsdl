# frozen_string_literal: true

module WSDL
  # Represents a SOAP operation that can be called.
  #
  # This class provides the interface for building and executing SOAP requests.
  # It allows you to set the request header and body, customize HTTP headers,
  # and execute the operation to receive a response.
  #
  # @example Basic operation call
  #   operation = client.operation('Service', 'Port', 'GetUser')
  #   operation.body = { user_id: 123 }
  #   response = operation.call
  #   puts response.body
  #
  # @example Using example messages
  #   operation = client.operation('Service', 'Port', 'CreateUser')
  #   operation.body = operation.example_body
  #   operation.body[:user][:name] = 'John Doe'
  #   operation.body[:user][:email] = 'john@example.com'
  #   response = operation.call
  #
  # @example Customizing the request
  #   operation = client.operation('Service', 'Port', 'SecureOperation')
  #   operation.header = { auth_token: 'secret' }
  #   operation.soap_action = 'CustomAction'
  #   operation.endpoint = 'https://other-server.example.com/soap'
  #   response = operation.call
  #
  # @example WS-Security with UsernameToken
  #   operation = client.operation('Service', 'Port', 'SecureOperation')
  #   operation.security.username_token('user', 'secret')
  #   response = operation.call
  #
  # @example WS-Security with X.509 signing
  #   cert = OpenSSL::X509::Certificate.new(File.read('cert.pem'))
  #   key = OpenSSL::PKey::RSA.new(File.read('key.pem'), 'password')
  #
  #   operation = client.operation('Service', 'Port', 'SecureOperation')
  #   operation.security.timestamp
  #   operation.security.signature(certificate: cert, private_key: key)
  #   response = operation.call
  #
  class Operation
    # Default encoding for SOAP messages.
    ENCODING = 'UTF-8'

    # Content-Type headers for different SOAP versions.
    CONTENT_TYPE = {
      '1.1' => 'text/xml',
      '1.2' => 'application/soap+xml'
    }.freeze

    # Creates a new Operation instance.
    #
    # @param operation_info [Parser::OperationInfo] the parsed operation definition
    # @param parser_result [Parser::Result] the parser result
    # @param http [Object] the HTTP adapter instance
    # @param pretty_print [Boolean] whether to format XML output with indentation
    #
    # @api private
    #
    def initialize(operation_info, parser_result, http, pretty_print: true)
      @operation_info = operation_info
      @parser_result = parser_result
      @http = http
      @pretty_print = pretty_print

      @endpoint = operation_info.endpoint
      @soap_version = operation_info.soap_version
      @soap_action = operation_info.soap_action
      @encoding = ENCODING
    end

    # @!attribute [rw] endpoint
    #   The SOAP endpoint URL.
    #   @return [String] the endpoint URL
    attr_accessor :endpoint

    # @!attribute [rw] soap_version
    #   The SOAP version to use ('1.1' or '1.2').
    #   @return [String] the SOAP version
    attr_accessor :soap_version

    # @!attribute [rw] soap_action
    #   The SOAPAction HTTP header value.
    #   @return [String, nil] the SOAP action
    attr_accessor :soap_action

    # @!attribute [rw] encoding
    #   The character encoding for the request.
    #   @return [String] the encoding (defaults to 'UTF-8')
    attr_accessor :encoding

    # @!attribute [rw] pretty_print
    #   Whether to format XML output with indentation and margins.
    #   Set to `false` for whitespace-sensitive SOAP servers.
    #   @return [Boolean] true if XML will be formatted (defaults to true)
    attr_accessor :pretty_print

    # Returns a Hash of HTTP headers to send with the request.
    #
    # Headers are automatically generated based on the SOAP version and
    # encoding. For SOAP 1.1, includes a SOAPAction header. For SOAP 1.2,
    # the action is included in the Content-Type header.
    #
    # @return [Hash{String => String}] the HTTP headers
    def http_headers
      return @http_headers if @http_headers

      headers = {}
      content_type = [CONTENT_TYPE[soap_version], "charset=#{encoding}"]

      case soap_version
      when '1.1'
        headers['SOAPAction'] = soap_action.nil? ? '' : %("#{soap_action}")
      when '1.2'
        content_type << %(action="#{soap_action}") if soap_action && !soap_action.empty?
      end

      headers['Content-Type'] = content_type.join(';')

      @http_headers = headers
    end

    # @!attribute [w] http_headers
    #   Sets custom HTTP headers for the request.
    #   @return [Hash{String => String}] the HTTP headers
    attr_writer :http_headers

    # @!attribute [rw] header
    #   The SOAP header data.
    #   @return [Hash, nil] the header hash
    attr_accessor :header

    # Generates an example header Hash based on the WSDL definition.
    #
    # Use this to get a template of the expected header structure,
    # then fill in the values as needed.
    #
    # @return [Hash] an example header hash with placeholder values
    def example_header
      Builder::ExampleMessage.build(@operation_info.input.header_parts)
    end

    # @!attribute [rw] body
    #   The SOAP body data.
    #   @return [Hash, nil] the body hash
    attr_accessor :body

    # Generates an example body Hash based on the WSDL definition.
    #
    # Use this to get a template of the expected body structure,
    # then fill in the values as needed.
    #
    # @return [Hash] an example body hash with placeholder values
    # @example
    #   body = operation.example_body
    #   # => { user: { name: "string", age: "int" } }
    #   body[:user][:name] = "John"
    #   body[:user][:age] = 30
    #   operation.body = body
    def example_body
      Builder::ExampleMessage.build(@operation_info.input.body_parts)
    end

    # Returns the input body parts used to build the request body.
    #
    # This provides detailed information about the expected structure
    # of the request body, including element names, types, and nesting.
    #
    # @return [Array<Array>] an array of body part definitions
    def body_parts
      @operation_info.input.body_parts.inject([]) { |memo, part| memo + part.to_a }
    end

    # Returns the security configuration for this operation.
    #
    # Use this to configure WS-Security features such as UsernameToken
    # authentication, timestamps, and X.509 certificate signing.
    #
    # @return [Security::Config] the security configuration
    #
    # @example UsernameToken authentication
    #   operation.security.username_token('user', 'secret')
    #
    # @example Digest authentication
    #   operation.security.username_token('user', 'secret', digest: true)
    #
    # @example Timestamp
    #   operation.security.timestamp(expires_in: 300)
    #
    # @example X.509 signing
    #   operation.security.signature(
    #     certificate: cert,
    #     private_key: key,
    #     digest_algorithm: :sha256
    #   )
    #
    def security
      @security ||= Security::Config.new
    end

    # Builds the SOAP request envelope XML.
    #
    # This method constructs the complete SOAP envelope including
    # the header and body based on the current {#header} and {#body}
    # values. If security is configured, the WS-Security header is
    # also applied.
    #
    # @return [String] the SOAP envelope XML
    def build
      @build ||= build_envelope
    end

    # @!attribute [rw] xml_envelope
    #   A custom XML envelope to use instead of building one.
    #
    #   Set this to bypass the normal message building and send
    #   a raw XML envelope directly.
    #
    #   @return [String, nil] the custom XML envelope
    attr_accessor :xml_envelope

    # Executes the SOAP operation and returns the response.
    #
    # If {#xml_envelope} is set, it will be sent directly.
    # Otherwise, the envelope is built from {#header} and {#body}.
    #
    # @return [Response] the SOAP response
    # @example
    #   operation.body = { user_id: 123 }
    #   response = operation.call
    #   puts response.body[:get_user_response][:user][:name]
    def call
      message = (xml_envelope.nil? ? build : xml_envelope)

      raw_response = @http.post(endpoint, http_headers, message)
      Response.new(
        raw_response,
        output_body_parts: @operation_info.output.body_parts,
        output_header_parts: @operation_info.output.header_parts,
        trust_store: security.verification_trust_store,
        check_validity: security.check_certificate_validity
      )
    end

    # Returns the input style for this operation.
    #
    # The style is a combination of the binding style and use,
    # such as 'document/literal' or 'rpc/literal'.
    #
    # @return [String] the input style (e.g., 'document/literal')
    def input_style
      @input_style ||= @operation_info.input_style
    end

    # Returns the output style for this operation.
    #
    # The style is a combination of the binding style and use,
    # such as 'document/literal' or 'rpc/literal'.
    #
    # @return [String] the output style (e.g., 'document/literal')
    def output_style
      @output_style ||= @operation_info.output_style
    end

    private

    # Builds the SOAP envelope with optional security header.
    #
    # @return [String] the complete SOAP envelope XML
    #
    def build_envelope
      envelope_xml = Builder::Envelope.new(@operation_info, header, body, pretty_print:).to_s

      if security.configured?
        security_header = Security::SecurityHeader.new(security)
        envelope_xml = security_header.apply(envelope_xml)
      end

      envelope_xml
    end
  end
end
