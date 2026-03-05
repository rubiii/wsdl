# frozen_string_literal: true

module WSDL
  module Request
    # Request DSL execution context.
    # rubocop:disable Metrics/ClassLength
    class DSLContext < BasicObject
      # Reserved DSL method names that cannot be used as element names directly.
      #
      # @return [Array<Symbol>]
      RESERVED_METHODS = %i[tag header body ws_security text cdata comment pi xmlns attribute].freeze

      def initialize(document:, security:, limits:)
        @document = document
        @security = security
        @limits = limits
        @section = :body
        @in_section_block = false
        @stack = []
        @element_count = 0
        @attribute_count = 0

        @namespaces = {
          'wsse' => ::WSDL::Security::Constants::NS::Security::WSSE,
          'wsu' => ::WSDL::Security::Constants::NS::Security::WSU,
          'ds' => ::WSDL::Security::Constants::NS::Signature::DS,
          'ec' => ::WSDL::Security::Constants::NS::Signature::EC,
          'env' => ::WSDL::NS::SOAP_1_1,
          'soap' => ::WSDL::NS::SOAP_1_1,
          'soap12' => ::WSDL::NS::SOAP_1_2,
          'xsi' => ::WSDL::NS::XSI
        }
      end

      # @return [Document]
      attr_reader :document

      # @return [WSDL::Security::Config]
      attr_reader :security

      # Universal element creator.
      # rubocop:disable Metrics/AbcSize
      def tag(name, *args, **keyword_attrs, &block)
        validate_depth!(@stack.length + 1)
        validate_element_count!(@element_count + 1)

        qname = name.to_s
        ::WSDL::Request::Names.validate_qname!(qname)
        prefix, local_name = ::WSDL::Request::Names.parse_qname(qname)

        namespace_uri = lookup_namespace(prefix)
        if prefix && namespace_uri.nil?
          ::Kernel.raise ::WSDL::RequestDslError, "Undeclared namespace prefix #{prefix.inspect} for #{qname.inspect}"
        end

        text_content, hash_attrs = parse_tag_args(args, keyword_attrs)
        node = ::WSDL::Request::Node.new(name: qname, prefix:, local_name:, namespace_uri:)

        hash_attrs.each do |attr_name, value|
          add_attribute(node, attr_name, value)
        end

        append_node(node)
        @element_count += 1

        node.children << ::WSDL::Request::TextNode.new(text_content.to_s) if text_content

        if block
          @stack << node
          instance_exec(&block)
          @stack.pop
        end

        node
      end
      # rubocop:enable Metrics/AbcSize

      # SOAP Header section.
      def header(&)
        with_section(:header, &)
      end

      # SOAP Body section.
      def body(&)
        with_section(:body, &)
      end

      # WS-Security request configuration.
      def ws_security(&block)
        ::Kernel.raise ::WSDL::RequestDslError, 'ws_security requires a block' unless block

        context = SecurityDSLContext.new(@security)
        context.instance_exec(&block)
      end

      # Adds text content node to the current element.
      def text(content)
        current_node!.children << ::WSDL::Request::TextNode.new(content.to_s)
      end

      # Adds CDATA node to the current element.
      def cdata(content)
        current_node!.children << ::WSDL::Request::CDataNode.new(content.to_s)
      end

      # Adds XML comment node to the current element.
      def comment(text)
        current_node!.children << ::WSDL::Request::Comment.new(text.to_s)
      end

      # Adds XML processing instruction node to the current element.
      def pi(target, content)
        ::WSDL::Request::Names.validate_ncname!(target, kind: 'processing instruction target')
        current_node!.children << ::WSDL::Request::ProcessingInstruction.new(target.to_s, content.to_s)
      end

      # Declares a namespace binding.
      def xmlns(prefix, uri)
        normalized_prefix = normalize_and_validate_prefix!(prefix)
        namespace_decl = ::WSDL::Request::NamespaceDecl.new(normalized_prefix, uri.to_s)
        @namespaces[normalized_prefix || ''] = uri.to_s
        @document.namespace_decls << namespace_decl
        @stack.last&.namespace_decls&.<<(namespace_decl)
      end

      # Adds an attribute to the current element.
      def attribute(name, value)
        add_attribute(current_node!, name, value)
      end

      # Internal document accessor used by Operation#prepare.
      def __document__
        @document
      end

      # Internal security accessor used by Operation#prepare.
      def __security__
        @security
      end

      # Explicitly reject unknown DSL methods.
      def method_missing(name, *_args, &)
        available = RESERVED_METHODS.map(&:inspect).join(', ')
        ::Kernel.raise ::WSDL::RequestDslError,
                       "Unknown request DSL method #{name.inspect}. " \
                       "Use tag('#{name}') for elements, or one of the reserved methods: #{available}"
      end

      def respond_to_missing?(_name, _include_private = false)
        false
      end

      private

      def parse_tag_args(args, keyword_attrs)
        positional = args.dup
        trailing_hash = positional.last.is_a?(::Hash) ? positional.pop : {}

        if positional.length > 1
          ::Kernel.raise ::WSDL::RequestDslError, 'tag accepts at most one positional content argument'
        end

        content = positional.first
        attrs = trailing_hash.merge(keyword_attrs)
        [content, attrs]
      end

      def with_section(section)
        ::Kernel.raise ::WSDL::RequestDslError, "#{section} requires a block" unless ::Kernel.block_given?

        if @in_section_block
          ::Kernel.raise ::WSDL::RequestDslError,
                         "Cannot nest #{section} inside another section block. " \
                         'header and body blocks must be at the top level of the request.'
        end

        previous = @section
        @section = section
        @in_section_block = true
        yield
      ensure
        @section = previous
        @in_section_block = false
      end

      def add_attribute(node, name, value)
        validate_attribute_count!(@attribute_count + 1)

        qname = name.to_s
        if qname.include?(':')
          add_qualified_attribute(node, qname, value)
        else
          add_unqualified_attribute(node, qname, value)
        end

        @attribute_count += 1
      end

      def add_qualified_attribute(node, qname, value)
        prefix, local_name = ::WSDL::Request::Names.parse_qname(qname)
        ::WSDL::Request::Names.validate_ncname!(prefix, kind: 'attribute prefix')
        ::WSDL::Request::Names.validate_ncname!(local_name, kind: 'attribute name')
        namespace_uri = lookup_namespace(prefix)
        validate_attribute_namespace!(prefix, qname, namespace_uri)
        validate_duplicate_qualified_attribute!(node, qname, namespace_uri, local_name)

        node.attributes << ::WSDL::Request::Attribute.new(qname, prefix, local_name, value.to_s, namespace_uri)
      end

      def add_unqualified_attribute(node, qname, value)
        ::WSDL::Request::Names.validate_ncname!(qname, kind: 'attribute name')
        validate_duplicate_unqualified_attribute!(node, qname)

        node.attributes << ::WSDL::Request::Attribute.new(qname, nil, qname, value.to_s, nil)
      end

      def validate_attribute_namespace!(prefix, qname, namespace_uri)
        return unless namespace_uri.nil?

        ::Kernel.raise ::WSDL::RequestDslError,
                       "Undeclared namespace prefix #{prefix.inspect} for attribute #{qname.inspect}"
      end

      def validate_duplicate_qualified_attribute!(node, qname, namespace_uri, local_name)
        key = "#{namespace_uri}:#{local_name}"
        return unless node.attributes.any? { |attr| "#{attr.namespace_uri}:#{attr.local_name}" == key }

        ::Kernel.raise ::WSDL::RequestDslError,
                       "Duplicate attribute #{qname.inspect} on element #{node.name.inspect}"
      end

      def validate_duplicate_unqualified_attribute!(node, qname)
        return unless node.attributes.any? { |attr| attr.prefix.nil? && attr.local_name == qname }

        ::Kernel.raise ::WSDL::RequestDslError,
                       "Duplicate attribute #{qname.inspect} on element #{node.name.inspect}"
      end

      def append_node(node)
        if @stack.empty?
          target = @section == :header ? @document.header : @document.body
          target << node
        else
          @stack.last.children << node
        end
      end

      def current_node!
        node = @stack.last
        return node if node

        ::Kernel.raise ::WSDL::RequestDslError, 'text/cdata/comment/pi/attribute require a surrounding tag block'
      end

      def normalize_and_validate_prefix!(prefix)
        normalized = prefix&.to_s
        normalized = nil if normalized&.empty?

        if normalized
          ::WSDL::Request::Names.validate_ncname!(normalized, kind: 'namespace prefix')
          ::WSDL::Request::Names.validate_prefix_override!(normalized)
        end

        normalized
      end

      def lookup_namespace(prefix)
        return nil if prefix.nil?

        @namespaces[prefix]
      end

      def validate_element_count!(count)
        limit = @limits.max_request_elements
        return unless limit
        return if count <= limit

        ::Kernel.raise ::WSDL::ResourceLimitError.new(
          "Request element count #{count} exceeds limit of #{limit}",
          limit_name: :max_request_elements,
          limit_value: limit,
          actual_value: count
        )
      end

      def validate_attribute_count!(count)
        limit = @limits.max_request_attributes
        return unless limit
        return if count <= limit

        ::Kernel.raise ::WSDL::ResourceLimitError.new(
          "Request attribute count #{count} exceeds limit of #{limit}",
          limit_name: :max_request_attributes,
          limit_value: limit,
          actual_value: count
        )
      end

      def validate_depth!(depth)
        limit = @limits.max_request_depth
        return unless limit
        return if depth <= limit

        ::Kernel.raise ::WSDL::ResourceLimitError.new(
          "Request depth #{depth} exceeds limit of #{limit}",
          limit_name: :max_request_depth,
          limit_value: limit,
          actual_value: depth
        )
      end

      # Nested WS-Security DSL context using implicit receiver.
      class SecurityDSLContext < BasicObject
        def initialize(config)
          @config = config
        end

        # Forwards known WS-Security DSL calls to the backing security config.
        #
        # @param name [Symbol] DSL method name
        # @return [Object] return value from {WSDL::Security::Config}
        # @raise [WSDL::RequestDslError] when the method is not supported
        def method_missing(name, ...)
          unless @config.respond_to?(name)
            ::Kernel.raise ::WSDL::RequestDslError, "Unknown ws_security DSL method #{name.inspect}"
          end

          @config.public_send(name, ...)
        end

        def respond_to_missing?(name, include_private = false)
          @config.respond_to?(name, include_private)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
