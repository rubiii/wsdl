# frozen_string_literal: true

require 'webrick'

module WSDL
  module TestService
    # Shared WEBrick-based mock SOAP server for all test services.
    #
    # Runs a single WEBrick instance that routes requests to different
    # services based on URL path. Each service is mounted at its own
    # path prefix (e.g. +/blz_service/+).
    #
    # The server starts lazily on first use and shuts down via
    # an +after(:suite)+ hook registered automatically.
    #
    # @example
    #   MockServer.instance.mount(:blz_service, service_definition)
    #   MockServer.instance.base_url(:blz_service) # => "http://127.0.0.1:PORT/blz_service/"
    #
    class MockServer
      # Returns the singleton server instance.
      #
      # @return [MockServer]
      def self.instance
        @instance ||= new
      end

      # Resets the singleton (for test isolation).
      #
      # @return [void]
      def self.reset!
        @instance&.stop
        @instance = nil
      end

      def initialize
        @port = nil
        @server = nil
        @thread = nil
        @services = {}
      end

      # Mounts a service definition at its name-based path.
      #
      # Starts the server if not already running. If the service is
      # already mounted, this is a no-op.
      #
      # @param name [Symbol] the service name (used as the URL path prefix)
      # @param service_definition [ServiceDefinition] the service to mount
      # @return [void]
      def mount(name, service_definition)
        return if @services.key?(name)

        ensure_running!
        @services[name] = service_definition
        @server.mount("/#{name}", SoapServlet, service_definition, name)
      end

      # Returns the WSDL URL for a mounted service.
      #
      # @param name [Symbol] the service name
      # @return [String] the URL to fetch the WSDL (e.g. "http://127.0.0.1:PORT/blz_service/?wsdl")
      def wsdl_url(name)
        raise "Service #{name.inspect} not mounted" unless @services.key?(name)

        "#{base_url(name)}?wsdl"
      end

      # Returns the base URL for a mounted service.
      #
      # @param name [Symbol] the service name
      # @return [String]
      def base_url(name)
        "http://127.0.0.1:#{@port}/#{name}/"
      end

      # Returns the server port.
      #
      # @return [Integer, nil]
      attr_reader :port

      # Stops the WEBrick server and clears all mounts.
      #
      # @return [void]
      def stop
        @server&.shutdown
        @thread&.join(5)
        @server = nil
        @thread = nil
        @port = nil
        @services.clear
      end

      private

      def ensure_running!
        return if @server

        @port = find_available_port
        @server = WEBrick::HTTPServer.new(
          Port: @port,
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )

        @thread = Thread.new { @server.start }
        wait_for_server
      end

      def find_available_port
        server = TCPServer.new('127.0.0.1', 0)
        port = server.addr[1]
        server.close
        port
      end

      def wait_for_server
        20.times do
          TCPSocket.new('127.0.0.1', @port).close
          return
        rescue Errno::ECONNREFUSED
          sleep 0.05
        end
        raise "Mock server failed to start on port #{@port}"
      end
    end

    # WEBrick servlet that handles WSDL and SOAP requests for a single service.
    #
    # Mounted by {MockServer} at a service-specific path prefix.
    #
    class SoapServlet < WEBrick::HTTPServlet::AbstractServlet
      # @param server [WEBrick::HTTPServer] the WEBrick server
      # @param service_definition [ServiceDefinition] the service to handle
      # @param service_name [Symbol] the service name (for URL rewriting)
      def initialize(server, service_definition, service_name)
        super(server)
        @service = service_definition
        @service_name = service_name
      end

      # rubocop:disable Naming/MethodName -- WEBrick API convention

      # Handles GET requests (serves the WSDL document).
      #
      # @param request [WEBrick::HTTPRequest]
      # @param response [WEBrick::HTTPResponse]
      # @return [void]
      def do_GET(request, response)
        if request.query_string&.include?('wsdl')
          base_url = MockServer.instance.base_url(@service_name)
          respond_with_xml(response, 200, @service.wsdl_xml(base_url))
        else
          response.status = 404
          response.body = 'Not Found'
        end
      end

      # Handles POST requests (processes SOAP requests).
      #
      # @param request [WEBrick::HTTPRequest]
      # @param response [WEBrick::HTTPResponse]
      # @return [void]
      def do_POST(request, response)
        handle_soap_request(request, response)
      rescue StandardError => e
        respond_with_xml(response, 500, soap_fault("#{e.class}: #{e.message}"))
      end
      # rubocop:enable Naming/MethodName

      private

      def handle_soap_request(request, response)
        soap_body = parse_soap_body(request.body)
        operation_name = detect_operation(request, soap_body)
        response_hash = @service.find_response(operation_name, soap_body)

        return respond_with_xml(response, 500, soap_fault('No matching response found')) unless response_hash

        respond_with_operation(response, operation_name, response_hash)
      end

      def respond_with_operation(response, operation_name, response_hash)
        wsdl_operation = @service.resolve_operation(operation_name)
        builder = WSDL::Response::Builder.new(
          schema_elements: wsdl_operation.contract.response.body.elements,
          soap_version: wsdl_operation.soap_version
        )

        xml = builder.to_xml(response_hash)
        xml = wrap_rpc_response(xml, wsdl_operation) if wsdl_operation.output_style == 'rpc/literal'

        respond_with_xml(response, 200, xml, soap_version: wsdl_operation.soap_version)
      end

      def respond_with_xml(response, status, body, soap_version: '1.1')
        response.status = status
        response['Content-Type'] = soap_content_type(soap_version)
        response.body = body
      end

      # Detects the operation name from the SOAPAction header or body element.
      #
      # Prefers the SOAPAction header when it uniquely identifies an operation.
      # Falls back to the first element name in the parsed SOAP body.
      def detect_operation(request, parsed_body)
        from_soap_action(request) || parsed_body.keys.first
      end

      def from_soap_action(request)
        raw = request['SOAPAction']
        return nil if raw.nil? || raw.empty?

        action = raw.delete('"')
        return nil if action.empty?

        soap_action_map[action]
      end

      def soap_action_map
        @soap_action_map ||= build_soap_action_map
      end

      def build_soap_action_map
        map = {}
        @service.defined_operations.each do |op_name|
          action = @service.resolve_operation(op_name).soap_action
          next if action.nil? || action.empty?

          map[action] = op_name
        end
        map
      end

      def parse_soap_body(xml)
        doc = Nokogiri::XML(xml)
        body = doc.at_xpath(
          '//env:Body | //soap:Body | //soap12:Body',
          'env' => WSDL::NS::SOAP_1_1,
          'soap' => WSDL::NS::SOAP_1_1,
          'soap12' => WSDL::NS::SOAP_1_2
        )
        return {} unless body

        WSDL::Response::Parser.parse(body, unwrap: true)
      end

      # Wraps builder output in an RPC response element.
      #
      # For RPC/literal, the SOAP body must contain a wrapper element
      # named +operationNameResponse+ with the binding's output namespace.
      def wrap_rpc_response(xml, wsdl_operation)
        doc = Nokogiri::XML(xml)
        body = find_soap_body(doc)
        return xml unless body

        wrapper = build_rpc_wrapper(doc, "#{wsdl_operation.name}Response",
                                    wsdl_operation.output_namespace)

        body.children.each do |child|
          wrapper.add_child(child)
        end
        body.add_child(wrapper)

        doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML |
                                   Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
      end

      def find_soap_body(doc)
        doc.at_xpath('//env:Body', 'env' => WSDL::NS::SOAP_1_1) ||
          doc.at_xpath('//env:Body', 'env' => WSDL::NS::SOAP_1_2)
      end

      def build_rpc_wrapper(doc, name, namespace_uri)
        wrapper = Nokogiri::XML::Node.new(name, doc)
        return wrapper unless namespace_uri

        ns = doc.root.add_namespace_definition(nil, namespace_uri) ||
             doc.root.namespace_definitions.find { |n| n.href == namespace_uri }
        wrapper.namespace = ns
        wrapper
      end

      def soap_content_type(soap_version)
        case soap_version
        when '1.2' then 'application/soap+xml; charset=utf-8'
        else 'text/xml; charset=utf-8'
        end
      end

      def soap_fault(message)
        <<~XML
          <env:Envelope xmlns:env="#{WSDL::NS::SOAP_1_1}">
            <env:Body>
              <env:Fault>
                <faultcode>env:Server</faultcode>
                <faultstring>#{message}</faultstring>
              </env:Fault>
            </env:Body>
          </env:Envelope>
        XML
      end
    end
  end
end
