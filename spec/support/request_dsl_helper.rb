# frozen_string_literal: true

module SpecSupport
  module RequestDSLEmitter
    module_function

    def emit_hash_section(context, section, value, expected_elements)
      return if value.nil?

      if section == :header
        context.header { SpecSupport::RequestDSLEmitter.emit_hash(context, value, expected_elements) }
      else
        context.body { SpecSupport::RequestDSLEmitter.emit_hash(context, value, expected_elements) }
      end
    end

    def emit_hash(context, hash, expected_elements)
      hash.each do |name, value|
        expected = resolve_expected_element(name.to_s, expected_elements)
        emit_element(context, name.to_s, value, expected)
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def emit_element(context, name, value, expected_element = nil)
      case value
      when Array
        value.each { |item| emit_element(context, name, item, expected_element) }
      when Hash
        attributes, content = split_attributes(value)
        text_value = extract_text_value(name, content)

        context.tag(name) do
          attributes.each do |attr_name, attr_value|
            context.attribute(attr_name, attr_value)
          end

          context.text(text_value) unless text_value.nil?
          unless content.empty?
            child_elements = expected_element&.children || []
            SpecSupport::RequestDSLEmitter.emit_hash(context, content, child_elements)
          end
        end
      when nil
        if expected_element&.nillable?
          context.tag(name) { context.attribute('xsi:nil', 'true') }
        else
          context.tag(name)
        end
      else
        context.tag(name, value)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def resolve_expected_element(name, expected_elements)
      return nil unless expected_elements

      expected_elements.find { |element| element.name == name }
    end

    def split_attributes(hash)
      attrs = {}
      content = {}

      hash.each do |key, value|
        key_text = key.to_s
        if key_text.start_with?('_')
          attrs[key_text.delete_prefix('_')] = value
        else
          content[key] = value
        end
      end

      [attrs, content]
    end

    def extract_text_value(name, content)
      symbol_key = name.to_sym
      return nil unless content.key?(name) || content.key?(symbol_key)

      key = content.key?(name) ? name : symbol_key
      value = content.delete(key)
      value.is_a?(Hash) || value.is_a?(Array) ? nil : value
    end
  end

  # Helpers for expressing request fixtures via the new request DSL.
  module RequestDSLHelper
    def request_body_paths(operation)
      contract_paths(operation.contract.request.body)
    end

    def request_template(operation, section:, mode: :full)
      part = section == :header ? operation.contract.request.header : operation.contract.request.body
      part.template(mode:).to_h
    end

    def apply_request(operation, body: nil, header: nil, strict_schema: true, &security_block)
      header_elements = operation.contract.request.header.elements
      body_elements = operation.contract.request.body.elements

      with_strict_schema(operation, strict_schema) do
        operation.request do
          SpecSupport::RequestDSLEmitter.emit_hash_section(self, :header, header, header_elements) if header
          SpecSupport::RequestDSLEmitter.emit_hash_section(self, :body, body, body_elements) if body
          ws_security { instance_exec(&security_block) } if security_block
        end
      end
    end

    def self.emit_hash_section(context, section, value, expected_elements)
      RequestDSLEmitter.emit_hash_section(context, section, value, expected_elements)
    end

    private

    def contract_paths(part_contract)
      part_contract.paths.map do |entry|
        path = entry.fetch(:path)
        data = entry.except(:path, :min_occurs, :max_occurs)
        data[:namespace] = nil unless data.key?(:namespace)
        data[:any_content] = true if data.delete(:wildcard)
        data.delete(:attributes) if data[:attributes] && data[:attributes].empty?
        [path, data]
      end
    end

    def with_strict_schema(operation, strict_schema)
      return yield if strict_schema.nil?

      previous_strict_schema = operation.instance_variable_get(:@strict_schema)
      operation.instance_variable_set(:@strict_schema, strict_schema)
      yield
    ensure
      operation.instance_variable_set(:@strict_schema, previous_strict_schema) unless strict_schema.nil?
    end
  end
end

RSpec.configure do |config|
  config.include SpecSupport::RequestDSLHelper
end
