# frozen_string_literal: true

module WSDL
  module Request
    # Detects conflicts between manual request content and generated WS-Security.
    class SecurityConflictDetector
      # Header element local names that conflict with generated WS-Security output.
      #
      # @return [Hash{String => Set<String>}]
      SECURITY_ELEMENT_CONFLICTS = {
        Security::Constants::NS::Security::WSSE => Set['Security', 'UsernameToken', 'BinarySecurityToken'],
        Security::Constants::NS::Security::WSU => Set['Timestamp'],
        Security::Constants::NS::Signature::DS => Set['Signature']
      }.freeze

      def initialize(document:, security:)
        @document = document
        @security = security
      end

      # @return [void]
      def validate!
        return unless @security.configured?

        detect_header_conflicts!
        detect_body_id_conflicts! if @security.signature?
      end

      private

      def detect_header_conflicts!
        each_element(@document.header) do |node|
          namespace = node.namespace_uri
          next unless namespace

          blocked = SECURITY_ELEMENT_CONFLICTS[namespace]
          next unless blocked
          next unless blocked.include?(node.local_name)

          raise RequestSecurityConflictError,
                "Manual header element #{node.name.inspect} conflicts with generated WS-Security content"
        end
      end

      def detect_body_id_conflicts!
        each_element(@document.body) do |node|
          node.attributes.each do |attribute|
            next unless attribute.namespace_uri == Security::Constants::NS::Security::WSU
            next unless attribute.local_name == 'Id'

            raise RequestSecurityConflictError,
                  "Manual attribute #{attribute.name.inspect} in Body conflicts with generated signature references"
          end
        end
      end

      def each_element(nodes, &)
        nodes.each do |node|
          yield(node)
          child_elements = node.children.grep(::WSDL::Request::Node)
          each_element(child_elements, &)
        end
      end
    end
  end
end
