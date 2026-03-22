# frozen_string_literal: true

require 'bigdecimal'

# Exhaustive schema-driven round-trip test.
#
# Verifies that parse(build(hash)) == hash for every eligible operation
# across all fixture WSDLs. Each operation gets a test with a full hash
# (all elements and attributes included, nillable elements set to nil)
# using fixed values per XSD type.
#
# This covers the *schema space* — ensuring every operation's schema
# structure works through the Builder and Parser pipeline. It complements
# the property-based test in spec/property/ which covers the *data space*
# with random values on randomly chosen operations.

module ExhaustiveRoundtripHelpers
  FIXED_VALUES = {
    string: 'a',
    integer: 0,
    boolean: true,
    float: 1.0,
    decimal: BigDecimal('0'),
    date: Date.new(2020, 1, 1),
    datetime: Time.utc(2020, 1, 1, 0, 0, 0),
    time: Time.utc(1970, 1, 1, 0, 0, 0),
    base64: 'test',
    hex_binary: 'test',
    list: %w[a b]
  }.freeze

  module_function

  def generate_full_hash(schema_elements)
    wrapper = schema_elements.first
    return {} unless wrapper

    wrapper.complex_type? ? full_complex(wrapper) : full_parts(schema_elements)
  end

  def full_parts(schema_elements)
    schema_elements.to_h { |el| [el.name.to_sym, full_value(el)] }
  end

  def full_complex(element)
    hash = {}

    element.attributes.each do |attr|
      hash[:"_#{attr.name}"] = fixed_simple(attr.base_type)
    end

    element.children.each do |child|
      hash[child.name.to_sym] = child_value(child)
    end

    hash
  end

  def child_value(child)
    return child.singular? ? nil : [nil] if child.nillable?

    child.singular? ? full_value(child) : [full_value(child)]
  end

  def full_value(element)
    element.simple_type? ? fixed_simple(element.base_type) : full_complex(element)
  end

  def fixed_simple(base_type)
    group = RoundtripCandidates.type_group_for(base_type)
    FIXED_VALUES.fetch(group, 'a')
  end
end

RSpec.describe 'Exhaustive schema round-trip' do
  include ExhaustiveRoundtripHelpers
  include RoundtripCandidates

  RoundtripCandidates.discover_candidates.each do |candidate|
    it candidate[:label] do
      hash = generate_full_hash(candidate[:schema_elements])

      xml = WSDL::Response::Builder.new(
        schema_elements: candidate[:schema_elements],
        soap_version: candidate[:soap_version],
        output_style: candidate[:output_style],
        operation_name: candidate[:operation_name],
        output_namespace: candidate[:output_namespace]
      ).to_xml(hash)

      node = extract_parse_node(xml, candidate)
      result = WSDL::Response::Parser.parse(node, schema: candidate[:schema_elements], unwrap: true)

      expect(result).to eq(expected_result(hash, candidate))
    end
  end
end
