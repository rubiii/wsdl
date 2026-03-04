# frozen_string_literal: true

module WSDL
  module Contract
    # Request template scaffold for request/header/body part contracts.
    class Template
      # Supported template rendering modes.
      #
      # - `:minimal` includes only required elements/attributes
      # - `:full` includes all known elements/attributes
      #
      # @return [Array<Symbol>]
      MODES = %i[minimal full].freeze

      # @param section [Symbol] :header or :body
      # @param elements [Array<WSDL::XML::Element>]
      # @param mode [Symbol] :minimal or :full
      def initialize(section:, elements:, mode:)
        validate_mode!(mode)

        @section = section
        @elements = elements
        @mode = mode
      end

      # Returns inspection-oriented structure of the selected part.
      #
      # @return [Hash{Symbol => Object}]
      def to_h
        @elements.each_with_object({}) do |element, memo|
          next unless include_element?(element)

          memo[element.name.to_sym] = template_value_for(element)
        end
      end

      # Returns a copy-pastable request DSL scaffold.
      #
      # @return [String]
      def to_dsl
        lines = ['operation.prepare do']

        if @section == :header
          lines << '  header do'
          append_element_lines(@elements, lines, 4)
          lines << '  end'
        else
          # Body content defaults to body section, no explicit wrapper needed
          append_element_lines(@elements, lines, 2)
        end

        lines << 'end'
        lines.join("\n")
      end

      private

      def validate_mode!(mode)
        return if MODES.include?(mode)

        raise ArgumentError, "Invalid template mode #{mode.inspect}. Expected :minimal or :full"
      end

      def include_element?(element)
        return true if @mode == :full

        element.required?
      end

      def include_attribute?(attribute)
        return true if @mode == :full

        !attribute.optional?
      end

      def placeholder_for_type(type)
        local = type.to_s.split(':').last
        local.nil? || local.empty? ? 'value' : local
      end

      def element_text_placeholder(element)
        placeholder_for_type(element.base_type)
      end

      def template_value_for(element)
        value = if element.simple_type?
          element_text_placeholder(element)
        else
          complex_template_value_for(element)
        end

        element.singular? ? value : [value]
      end

      def complex_template_value_for(element)
        hash = {}

        append_template_attributes(hash, element.attributes)
        append_template_children(hash, element.children)
        append_wildcard_template_value(hash, element)

        hash
      end

      def append_template_attributes(hash, attributes)
        attributes.each do |attribute|
          next unless include_attribute?(attribute)

          hash[:"_#{attribute.name}"] = attribute.base_type
        end
      end

      def append_template_children(hash, children)
        children.each do |child|
          next unless include_element?(child)

          hash[child.name.to_sym] = template_value_for(child)
        end
      end

      def append_wildcard_template_value(hash, element)
        return unless @mode == :full && element.any_content?

        hash[:'(any)'] = 'arbitrary XML content allowed'
      end

      def append_element_lines(elements, lines, indent)
        elements.each do |element|
          next unless include_element?(element)

          append_single_element_lines(element, lines, indent)
        end
      end

      def append_single_element_lines(element, lines, indent)
        prefix = ' ' * indent

        if element.simple_type?
          append_simple_element_line(element, lines, prefix)
          return
        end

        lines << "#{prefix}tag('#{element.name}') do"
        append_attribute_lines(element, lines, prefix)
        append_element_lines(element.children, lines, indent + 2)
        append_wildcard_line(element, lines, prefix)
        lines << "#{prefix}end"
      end

      def append_simple_element_line(element, lines, prefix)
        lines << "#{prefix}tag('#{element.name}', '#{element_text_placeholder(element)}')"
      end

      def append_attribute_lines(element, lines, prefix)
        element.attributes.each do |attribute|
          next unless include_attribute?(attribute)

          value = placeholder_for_type(attribute.base_type)
          lines << "#{prefix}  attribute('#{attribute.name}', '#{value}')"
        end
      end

      def append_wildcard_line(element, lines, prefix)
        return unless @mode == :full && element.any_content?

        lines << "#{prefix}  # xs:any wildcard content allowed"
      end
    end
  end
end
