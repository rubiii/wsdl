# frozen_string_literal: true

require 'builder'
require 'wsdl/message'

class WSDL
  # Builds SOAP envelopes for operation requests.
  #
  # This class constructs the complete SOAP envelope XML including
  # the header and body sections. It handles namespace registration
  # and supports both document and RPC style operations.
  #
  # @api private
  #
  class Envelope
    # Namespace ID prefix used for registered namespaces.
    NSID = 'lol'

    # Creates a new Envelope instance.
    #
    # @param operation [Definition::Operation] the operation definition
    # @param header [Hash, nil] the SOAP header data
    # @param body [Hash, nil] the SOAP body data
    def initialize(operation, header, body)
      @logger = Logging.logger[self]

      @operation = operation
      @header = header || {}
      @body = body || {}

      @nsid_counter = -1
      @namespaces = {}
    end

    # Registers a namespace and returns its namespace ID.
    #
    # If the namespace has already been registered, returns the
    # existing namespace ID. Otherwise, creates a new one.
    #
    # @param namespace [String] the namespace URI to register
    # @return [String] the namespace ID (e.g., 'lol0', 'lol1')
    def register_namespace(namespace)
      @namespaces[namespace] ||= create_nsid
    end

    # Builds and returns the complete SOAP envelope XML.
    #
    # @return [String] the SOAP envelope XML string
    def to_s
      build_envelope(build_header, build_body)
    end

    private

    # Creates a new unique namespace ID.
    #
    # @return [String] a new namespace ID
    def create_nsid
      @nsid_counter += 1
      "#{NSID}#{@nsid_counter}"
    end

    # Builds the SOAP header XML.
    #
    # @return [String] the header XML, or empty string if no header data
    def build_header
      return '' if @header.empty?

      Message.new(self, @operation.input.header_parts).build(@header)
    end

    # Builds the SOAP body XML.
    #
    # For RPC-style operations, wraps the body in an additional element.
    #
    # @return [String] the body XML, or empty string if no body data
    def build_body
      return '' if @body.empty?

      body = Message.new(self, @operation.input.body_parts).build(@body)

      if rpc_call?
        build_rpc_wrapper(body)
      else
        body
      end
    end

    # Builds the complete SOAP envelope with header and body.
    #
    # @param header [String] the built header XML
    # @param body [String] the built body XML
    # @return [String] the complete envelope XML
    def build_envelope(header, body)
      builder = Builder::XmlMarkup.new(indent: 2)

      builder.tag! :env, :Envelope, collect_namespaces do |xml|
        xml.tag!(:env, :Header) do |xml|
          xml << header
        end
        xml.tag!(:env, :Body) { |xml| xml << body }
      end

      builder.target!
    end

    # Builds the RPC wrapper element around the body content.
    #
    # @param body [String] the body content to wrap
    # @return [String] the wrapped body XML
    def build_rpc_wrapper(body)
      name = @operation.name
      namespace = @operation.binding_operation.input_body[:namespace]
      nsid = register_namespace(namespace) if namespace

      tag = [nsid, name].compact.join(':')

      format('<%<tag>s>%<body>s</%<tag>s>', tag: tag, body: body)
    end

    # Returns whether this is an RPC-style call.
    #
    # @return [Boolean] true if the operation uses RPC style
    def rpc_call?
      @operation.binding_operation.style == 'rpc'
    end

    # Collects all namespaces for the envelope element.
    #
    # Includes all registered namespaces plus the SOAP envelope namespace
    # appropriate for the SOAP version being used.
    #
    # @return [Hash<String, String>] namespace declarations
    def collect_namespaces
      # registered namespaces
      namespaces = @namespaces.each_with_object({}) do |(namespace, nsid), memo|
        memo["xmlns:#{nsid}"] = namespace
      end

      # envelope namespace
      namespaces['xmlns:env'] = case @operation.soap_version
      when '1.1' then 'http://schemas.xmlsoap.org/soap/envelope/'
      when '1.2' then 'http://www.w3.org/2003/05/soap-envelope'
      end

      namespaces
    end
  end
end
