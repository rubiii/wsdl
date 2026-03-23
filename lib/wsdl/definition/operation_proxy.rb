# frozen_string_literal: true

module WSDL
  class Definition
    # Duck-type proxy for {Parser::OperationInfo} backed by Definition data.
    #
    # Allows {Operation} and {Contract::OperationContract} to work with
    # Definition element hashes without modification — they call the same
    # methods they would on a real {Parser::OperationInfo}.
    #
    # @api private
    #
    class OperationProxy
      # @param data [Hash{Symbol => Object}] operation hash from Definition internal data
      # @param endpoint [String] the SOAP endpoint URL for this operation's port
      def initialize(data, endpoint:)
        @data = data
        @endpoint = endpoint
      end

      # @return [String] operation name
      def name
        @data[:name]
      end

      # @return [String] SOAP endpoint URL
      attr_reader :endpoint

      # @return [String, nil] SOAP action URI
      def soap_action
        @data[:soap_action]
      end

      # @return [String, nil] SOAP version ('1.1' or '1.2')
      def soap_version
        @data[:soap_version]
      end

      # @return [String] input binding style (e.g. 'document/literal')
      def input_style
        @data[:input_style]
      end

      # @return [String, nil] output binding style, or nil for one-way operations
      def output_style
        @data[:output_style]
      end

      # @return [MessageProxy] input message definition with header and body parts
      def input
        @input ||= MessageProxy.new(@data[:input])
      end

      # @return [MessageProxy, nil] output message definition, or nil for one-way operations
      def output
        return @output if defined?(@output)

        @output = @data[:output] ? MessageProxy.new(@data[:output]) : nil
      end

      # @return [BindingProxy] binding protocol details
      def binding_operation
        @binding_operation ||= BindingProxy.new(@data)
      end
    end

    # Duck-type proxy for {Parser::Input}/{Parser::Output} message parts.
    #
    # Wraps Definition element hashes as {ElementHash} arrays, providing
    # the same +header_parts+ and +body_parts+ interface.
    #
    # @api private
    #
    class MessageProxy
      # @param data [Hash{Symbol => Object}] message hash with +:header+ and +:body+ keys
      def initialize(data)
        @data = data
      end

      # @return [Array<ElementHash>] header part elements
      def header_parts
        @header_parts ||= wrap_elements(@data[:header])
      end

      # @return [Array<ElementHash>] body part elements
      def body_parts
        @body_parts ||= wrap_elements(@data[:body])
      end

      private

      def wrap_elements(hashes)
        hashes.map { |h| ElementHash.new(h) }.freeze
      end
    end

    # Duck-type proxy for {Parser::BindingOperation} protocol details.
    #
    # Provides the +input_body+ and +output_body+ hash accessors that
    # {Operation} reads for RPC namespace resolution.
    #
    # @api private
    #
    class BindingProxy
      # @param data [Hash{Symbol => Object}] operation hash from Definition internal data
      def initialize(data)
        @data = data
      end

      # @return [Hash{Symbol => String}] input body attributes (namespace for RPC wrapping)
      def input_body
        { namespace: @data[:rpc_input_namespace] }
      end

      # @return [Hash{Symbol => String}] output body attributes (namespace for RPC responses)
      def output_body
        { namespace: @data[:rpc_output_namespace] }
      end
    end
  end
end
