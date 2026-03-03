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

      # @return [Array<WSDL::XML::Element>]
      attr_reader :elements

      # Flat path metadata for this part.
      #
      # @return [Array<Hash{Symbol => Object}>]
      def paths
        @elements.flat_map(&:to_a).map do |path, data|
          {
            path: path,
            namespace: data[:namespace],
            form: data[:form],
            singular: data[:singular],
            min_occurs: data[:min_occurs],
            max_occurs: data[:max_occurs],
            type: data[:type],
            recursive_type: data[:recursive_type],
            attributes: data[:attributes],
            wildcard: data[:any_content] ? true : false
          }.compact
        end
      end

      # Hierarchical structure metadata for this part.
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

      def element_tree(element)
        {
          name: element.name,
          namespace: element.namespace,
          form: element.form,
          min_occurs: element.min_occurs,
          max_occurs: element.max_occurs,
          required: element.required?,
          nillable: element.nillable?,
          singular: element.singular?,
          type: element.base_type,
          wildcard: element.any_content?,
          attributes: element.attributes.map { |attr| attribute_tree(attr) },
          children: element.children.map { |child| element_tree(child) }
        }.compact
      end

      def attribute_tree(attribute)
        {
          name: attribute.name,
          type: attribute.base_type,
          required: !attribute.optional?
        }
      end
    end
  end
end
