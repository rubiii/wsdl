# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Contract::Template do
  # rubocop:disable Metrics/ParameterLists
  def build_element(name:, namespace: nil, base_type: nil, children: [], attributes: [],
                    any_content: false, min_occurs: '1', max_occurs: '1')
    el = WSDL::XML::Element.new
    el.name = name
    el.namespace = namespace
    el.base_type = base_type
    el.children = children
    el.any_content = any_content
    el.min_occurs = min_occurs
    el.max_occurs = max_occurs
    el.attributes = attributes unless attributes.empty?
    el
  end
  # rubocop:enable Metrics/ParameterLists

  def build_attribute(name:, base_type: 'xsd:string', use: 'required')
    attr = WSDL::XML::Attribute.new
    attr.name = name
    attr.base_type = base_type
    attr.use = use
    attr
  end

  describe 'elements with attributes' do
    let(:attr_required) { build_attribute(name: 'id', base_type: 'xsd:integer') }
    let(:attr_optional) { build_attribute(name: 'lang', base_type: 'xsd:string', use: 'optional') }
    let(:element) do
      build_element(
        name: 'Item',
        children: [build_element(name: 'Value', base_type: 'xsd:string')],
        attributes: [attr_required, attr_optional]
      )
    end

    it 'includes required attributes in minimal mode to_h' do
      template = described_class.new(section: :body, elements: [element], mode: :minimal)
      hash = template.to_h

      expect(hash[:Item][:_id]).to eq('xsd:integer')
      expect(hash[:Item]).not_to have_key(:_lang)
    end

    it 'includes all attributes in full mode to_h' do
      template = described_class.new(section: :body, elements: [element], mode: :full)
      hash = template.to_h

      expect(hash[:Item][:_id]).to eq('xsd:integer')
      expect(hash[:Item][:_lang]).to eq('xsd:string')
    end

    it 'renders attribute lines in to_dsl' do
      template = described_class.new(section: :body, elements: [element], mode: :full)
      dsl = template.to_dsl

      expect(dsl).to include("attribute('id', 'integer')")
      expect(dsl).to include("attribute('lang', 'string')")
    end

    it 'skips optional attributes in minimal mode to_dsl' do
      template = described_class.new(section: :body, elements: [element], mode: :minimal)
      dsl = template.to_dsl

      expect(dsl).to include("attribute('id', 'integer')")
      expect(dsl).not_to include("attribute('lang'")
    end
  end

  describe 'elements with wildcard (any_content)' do
    let(:element) do
      build_element(
        name: 'Container',
        children: [build_element(name: 'Fixed', base_type: 'xsd:string')],
        any_content: true
      )
    end

    it 'includes wildcard marker in full mode to_h' do
      template = described_class.new(section: :body, elements: [element], mode: :full)
      hash = template.to_h

      expect(hash[:Container][:'(any)']).to eq('arbitrary XML content allowed')
    end

    it 'excludes wildcard marker in minimal mode to_h' do
      template = described_class.new(section: :body, elements: [element], mode: :minimal)
      hash = template.to_h

      expect(hash[:Container]).not_to have_key(:'(any)')
    end

    it 'renders wildcard comment in full mode to_dsl' do
      template = described_class.new(section: :body, elements: [element], mode: :full)
      dsl = template.to_dsl

      expect(dsl).to include('# xs:any wildcard content allowed')
    end

    it 'excludes wildcard comment in minimal mode to_dsl' do
      template = described_class.new(section: :body, elements: [element], mode: :minimal)
      dsl = template.to_dsl

      expect(dsl).not_to include('xs:any')
    end
  end
end
