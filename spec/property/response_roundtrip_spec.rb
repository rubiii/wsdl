# frozen_string_literal: true

# rubocop:disable Style/MultilineBlockChain

require 'rantly'
require 'rantly/rspec_extensions'
require 'bigdecimal'

module RoundtripPropertyHelpers
  module_function

  def type_group_for(base_type)
    RoundtripCandidates.type_group_for(base_type)
  end

  # ============================================================
  # Rantly-based hash generation from schema elements
  # ============================================================

  def generate_random_hash(rantly, schema_elements)
    wrapper = schema_elements.first
    return {} unless wrapper

    if wrapper.complex_type?
      generate_complex_hash(rantly, wrapper)
    else
      schema_elements.to_h { |el| [el.name.to_sym, generate_element_value(rantly, el)] }
    end
  end

  OPTIONAL_STRATEGIES = %i[minimal full random].freeze

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- recursive tree walk
  def generate_complex_hash(rantly, element, strategy: rantly.choose(*OPTIONAL_STRATEGIES))
    hash = {}

    element.attributes.each do |attr|
      next if attr.optional? && skip_optional?(rantly, strategy)

      hash[:"_#{attr.name}"] = generate_simple_value(rantly, attr.base_type)
    end

    element.children.each do |child|
      next if child.optional? && skip_optional?(rantly, strategy)

      if child.singular? && child.nillable? && rantly.boolean
        hash[child.name.to_sym] = nil
      elsif child.singular?
        hash[child.name.to_sym] = generate_element_value(rantly, child, strategy:)
      else
        min = [child.min_occurs.to_i, 1].max
        max = child.max_occurs == 'unbounded' ? min + 2 : [child.max_occurs.to_i, min].max
        count = rantly.range(min, max)
        hash[child.name.to_sym] = Array.new(count) {
          child.nillable? && rantly.boolean ? nil : generate_element_value(rantly, child, strategy:)
        }
      end
    end

    hash
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def skip_optional?(rantly, strategy)
    case strategy
    when :minimal then true
    when :full    then false
    else rantly.boolean
    end
  end

  def generate_element_value(rantly, element, strategy: :random)
    if element.simple_type?
      generate_simple_value(rantly, element.base_type)
    else
      generate_complex_hash(rantly, element, strategy:)
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity -- type dispatch, case branches are trivial
  def generate_simple_value(rantly, base_type)
    case type_group_for(base_type)
    when :string   then random_string(rantly)
    when :integer  then rantly.range(-1000, 1000)
    when :boolean  then rantly.boolean
    when :float    then (rantly.range(-10_000, 10_000) / 100.0).round(2)
    when :decimal  then BigDecimal(rantly.range(-10_000, 10_000)) / 100
    when :date     then Date.new(rantly.range(2020, 2025), rantly.range(1, 12), rantly.range(1, 28))
    when :datetime   then random_datetime(rantly)
    when :time       then random_time(rantly)
    when :base64, :hex_binary
      rantly.sized(rantly.range(3, 10)) { rantly.string(:alpha) }
    when :list
      Array.new(rantly.range(1, 3)) { rantly.sized(rantly.range(3, 8)) { rantly.string(:alpha) } }
    else rantly.sized(rantly.range(3, 10)) { rantly.string(:alpha) } # rubocop:disable Lint/DuplicateBranch -- intentional fallback for unknown types
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  XML_SPECIAL_CHARS = ['<', '>', '&', '"', "'", 'foo & bar', 'a < b > c', 'x="y"'].freeze

  def random_string(rantly)
    base = rantly.sized(rantly.range(3, 10)) { rantly.string(:alpha) }
    return base if rantly.range(0, 3) > 0

    # ~25% of the time, inject XML-significant characters
    base + rantly.choose(*XML_SPECIAL_CHARS)
  end

  def random_datetime(rantly)
    Time.utc(rantly.range(2020, 2025), rantly.range(1, 12), rantly.range(1, 28),
      rantly.range(0, 23), rantly.range(0, 59), rantly.range(0, 59))
  end

  def random_time(rantly)
    Time.utc(1970, 1, 1, rantly.range(0, 23), rantly.range(0, 59), rantly.range(0, 59))
  end
end

RSpec.describe 'Response round-trip property' do
  include RoundtripCandidates

  let(:trial_count) { Integer(ENV.fetch('PROPERTY_TRIALS', 100)) }
  let(:candidates) { RoundtripCandidates.discover_candidates }

  it 'parse(build(hash)) preserves the hash' do
    skip 'no suitable candidates found' if candidates.empty?

    # Capture for use inside property_of block (self changes to Rantly)
    ops = candidates

    property_of {
      candidate = choose(*ops)
      hash = RoundtripPropertyHelpers.generate_random_hash(self, candidate[:schema_elements])
      guard !hash.empty?
      [candidate, hash]
    }.check(trial_count) do |(candidate, hash)|
      xml = WSDL::Response::Builder.new(
        schema_elements: candidate[:schema_elements],
        soap_version: candidate[:soap_version],
        output_style: candidate[:output_style],
        operation_name: candidate[:operation_name],
        output_namespace: candidate[:output_namespace]
      ).to_xml(hash)

      node = extract_parse_node(xml, candidate)
      result = WSDL::Response::Parser.parse(node, schema: candidate[:schema_elements], unwrap: true)

      expected = expected_result(hash, candidate)

      expect(result).to eq(expected), lambda {
        [
          "Round-trip failed for #{candidate[:label]}",
          "  Input:    #{hash.inspect}",
          "  Expected: #{expected.inspect}",
          "  Got:      #{result.inspect}"
        ].join("\n")
      }
    end
  end
end

# rubocop:enable Style/MultilineBlockChain
