# frozen_string_literal: true

module WSDL
  module Request
    # Schema-aware validator for request envelope documents.
    class Validator
      def initialize(contract:, strict_schema:, schema_complete:)
        @contract = contract
        @strict_schema = strict_schema
        @schema_complete = schema_complete
      end

      # @param document [Document]
      # @return [void]
      def validate!(document)
        validate_schema_completeness!

        validate_section!(document.header, @contract.request.header.elements, section: :header)
        validate_section!(document.body, @contract.request.body.elements, section: :body)
      end

      private

      def validate_schema_completeness!
        return unless @strict_schema
        return if @schema_complete

        raise RequestValidationError,
              'Strict request validation requires complete operation-relevant schema metadata. '
      end

      def validate_section!(nodes, expected_elements, section:)
        counts = count_and_validate_nodes!(nodes, expected_elements, section:)
        validate_required_elements!(counts, expected_elements, section:)
      end

      def count_and_validate_nodes!(nodes, expected_elements, section:)
        counts = ::Hash.new(0)

        nodes.each do |node|
          expected = resolve_expected(node, expected_elements)
          if expected
            counts[expected] += 1
            validate_node!(node, expected)
            next
          end

          next unless @strict_schema

          raise_namespace_mismatch_if_known_name!(node, expected_elements, context: "in #{section}")
          raise_unknown_section_element!(node, section:)
        end

        counts
      end

      def raise_unknown_section_element!(node, section:)
        raise RequestValidationError,
              "Unknown #{section} element #{node.name.inspect} for #{@contract.style} operation"
      end

      def validate_required_elements!(counts, expected_elements, section:)
        return unless @strict_schema

        expected_elements.each do |expected|
          min = expected.min_occurs.to_i
          next unless min.positive?
          next if counts[expected] >= min

          raise RequestValidationError,
                "Missing required #{section} element #{expected.name.inspect}"
        end

        validate_max_occurs_for_section!(counts, expected_elements, section:)
      end

      def validate_max_occurs_for_section!(counts, expected_elements, section:)
        expected_elements.each do |expected|
          next if expected.max_occurs == 'unbounded'
          next if counts[expected] <= expected.max_occurs.to_i

          raise RequestValidationError,
                "Element #{expected.name.inspect} exceeds maxOccurs=#{expected.max_occurs} in #{section}"
        end
      end

      def resolve_expected(node, expected_elements)
        expected_elements.find do |expected|
          next false unless expected.name == node.local_name

          if expected.form == 'qualified'
            node.namespace_uri.nil? || node.namespace_uri == expected.namespace
          else
            node.namespace_uri.nil?
          end
        end
      end

      def validate_node!(node, expected)
        node.resolved_element = expected
        apply_namespace_resolution!(node, expected)

        validate_attributes!(node, expected)
        validate_children!(node, expected)
      end

      def apply_namespace_resolution!(node, expected)
        return unless expected.form == 'qualified'
        return if node.namespace_uri == expected.namespace
        return resolve_missing_namespace!(node, expected) if node.namespace_uri.nil?
        return unless @strict_schema

        raise RequestValidationError,
              "Element #{node.name.inspect} namespace #{node.namespace_uri.inspect} does not match expected " \
              "#{expected.namespace.inspect}"
      end

      def validate_attributes!(node, expected)
        expected_attributes = expected.attributes.to_h { |attribute| [attribute.name, attribute] }
        present = ::Hash.new(0)

        node.attributes.each do |attribute|
          record_attribute_presence!(attribute, expected_attributes, present, node)
        end

        validate_required_attributes!(expected.attributes, present, node)
      end

      def validate_children!(node, expected)
        element_children = node.children.grep(::WSDL::Request::Node)
        expected_children = expected.children
        wildcard = expected.any_content?
        state = { counts: ::Hash.new(0), last_known_index: -1 }

        element_children.each do |child|
          expected_child = resolve_expected(child, expected_children)
          if expected_child
            validate_known_child!(child, expected_child, expected_children, state, node)
            next
          end

          next unless @strict_schema && !wildcard

          raise_namespace_mismatch_if_known_name!(child, expected_children, context: "under #{node.name.inspect}")
          raise_unknown_child!(child, node)
        end

        validate_expected_child_counts!(expected_children, state[:counts], node)
      end

      def resolve_missing_namespace!(node, expected)
        node.namespace_uri = expected.namespace
      end

      def record_attribute_presence!(attribute, expected_attributes, present, node)
        if expected_attributes.key?(attribute.local_name)
          present[attribute.local_name] += 1
          return
        end

        return unless @strict_schema && !xsi_nil_attribute?(attribute)

        raise RequestValidationError,
              "Unknown attribute #{attribute.name.inspect} on element #{node.name.inspect}"
      end

      def validate_required_attributes!(expected_attributes, present, node)
        return unless @strict_schema

        expected_attributes.each do |expected_attribute|
          next if expected_attribute.optional?
          next if present[expected_attribute.name].positive?

          raise RequestValidationError,
                "Missing required attribute #{expected_attribute.name.inspect} on element #{node.name.inspect}"
        end
      end

      def validate_known_child!(child, expected_child, expected_children, state, node)
        index = validate_child_order!(child, expected_child, expected_children, state[:last_known_index], node)
        state[:counts][expected_child] += 1
        validate_node!(child, expected_child)
        state[:last_known_index] = index || state[:last_known_index]
      end

      def validate_child_order!(child, expected_child, expected_children, last_known_index, node)
        index = expected_children.index(expected_child)
        if @strict_schema && index && index < last_known_index
          raise RequestValidationError,
                "Element order mismatch under #{node.name.inspect}: received #{child.name.inspect} out of order"
        end

        index
      end

      def raise_unknown_child!(child, node)
        raise RequestValidationError,
              "Unknown child element #{child.name.inspect} under #{node.name.inspect}"
      end

      def raise_namespace_mismatch_if_known_name!(node, expected_elements, context:)
        return unless node.namespace_uri

        candidates = candidates_for_local_name(node, expected_elements)
        return if candidates.empty?

        raise_qualified_namespace_mismatch!(node, candidates, context:)
        raise_unqualified_namespace_mismatch!(node, context:)
      end

      def candidates_for_local_name(node, expected_elements)
        expected_elements.select { |expected| expected.name == node.local_name }
      end

      def raise_qualified_namespace_mismatch!(node, candidates, context:)
        expected_namespaces = qualified_expected_namespaces(candidates)
        return if expected_namespaces.empty?

        expected_ns = expected_namespaces.one? ? expected_namespaces.first.inspect : expected_namespaces.inspect
        raise RequestValidationError,
              "Element #{node.name.inspect} namespace #{node.namespace_uri.inspect} does not match expected " \
              "namespace #{expected_ns} for element #{node.local_name.inspect} #{context}"
      end

      def qualified_expected_namespaces(candidates)
        candidates
          .select { |expected| expected.form == 'qualified' }
          .map(&:namespace)
          .uniq
      end

      def raise_unqualified_namespace_mismatch!(node, context:)
        raise RequestValidationError,
              "Element #{node.name.inspect} must be unqualified (no namespace) for element " \
              "#{node.local_name.inspect} #{context}"
      end

      def validate_expected_child_counts!(expected_children, counts, node)
        return unless @strict_schema

        expected_children.each do |expected_child|
          validate_child_min_occurs!(expected_child, counts, node)
          validate_child_max_occurs!(expected_child, counts, node)
        end
      end

      def validate_child_min_occurs!(expected_child, counts, node)
        min = expected_child.min_occurs.to_i
        return unless counts[expected_child] < min

        raise RequestValidationError,
              "Missing required child element #{expected_child.name.inspect} under #{node.name.inspect}"
      end

      def validate_child_max_occurs!(expected_child, counts, node)
        return if expected_child.max_occurs == 'unbounded'

        max = expected_child.max_occurs.to_i
        return unless max.positive? && counts[expected_child] > max

        raise RequestValidationError,
              "Element #{expected_child.name.inspect} exceeds maxOccurs=#{expected_child.max_occurs} " \
              "under #{node.name.inspect}"
      end

      def xsi_nil_attribute?(attribute)
        attribute.namespace_uri == ::WSDL::NS::XSI && attribute.local_name == 'nil'
      end
    end
  end
end
