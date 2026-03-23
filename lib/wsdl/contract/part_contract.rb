# frozen_string_literal: true

module WSDL
  module Contract
    # Immutable contract for a request/response message part section.
    class PartContract
      # @param elements [Array<WSDL::XML::Element>]
      # @param section [Symbol] :header or :body
      def initialize(elements, section:)
        @elements = elements.freeze
        @section = section
        freeze
      end

      # Returns the frozen collection of elements for this part.
      #
      # The array itself is frozen; individual elements should be treated as
      # read-only introspection objects.
      #
      # @return [Array<WSDL::XML::Element>]
      attr_reader :elements

      # Flat path metadata for this part.
      #
      # Returns a fresh array of hashes on each call. Mutating the returned
      # collection does not affect the contract's internal state.
      #
      # @return [Array<Hash{Symbol => Object}>]
      def paths
        @elements.flat_map(&:to_a).map do |path, data|
          {
            path: path,
            kind: data[:kind],
            namespace: data[:namespace],
            form: data[:form],
            singular: data[:singular],
            min_occurs: data[:min_occurs],
            max_occurs: data[:max_occurs],
            type: data[:type],
            list: data[:list],
            recursive_type: data[:recursive_type],
            attributes: data[:attributes],
            wildcard: data[:any_content]
          }.compact
        end
      end

      # Hierarchical structure metadata for this part.
      #
      # Returns a fresh array of hashes on each call. Mutating the returned
      # collection does not affect the contract's internal state.
      #
      # @return [Array<Hash{Symbol => Object}>]
      def tree
        @elements.map { |element| element_tree(element) }
      end

      # Returns a request template helper.
      #
      # @param mode [Symbol] :minimal or :full
      # @return [Template]
      def template(mode: :minimal)
        Template.new(section: @section, elements: @elements, mode:)
      end

      private

      # rubocop:disable Metrics/AbcSize -- straightforward property extraction
      def element_tree(element)
        result = {
          name: element.name,
          kind: element.kind,
          namespace: element.namespace,
          form: element.form,
          min_occurs: element.min_occurs,
          max_occurs: element.max_occurs,
          required: element.required?,
          nillable: element.nillable?,
          singular: element.singular?,
          type: element.base_type,
          attributes: element.attributes.map(&:to_h),
          children: element.children.map { |child| element_tree(child) }
        }
        result[:list] = element.list? if element.simple_type?
        result[:wildcard] = element.any_content? if element.complex_type?
        result.compact
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
