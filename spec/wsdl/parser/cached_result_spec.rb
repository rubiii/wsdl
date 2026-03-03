# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Parser::CachedResult do
  let(:wsdl) { fixture('wsdl/amazon') }
  let(:limits) { WSDL::Limits.new }
  let(:sandbox_paths) { [File.dirname(File.expand_path(wsdl))] }

  let(:adapter_class) do
    Class.new do
      attr_reader :cache_key

      def initialize(cache_key)
        @cache_key = cache_key
      end
    end
  end

  describe '.load' do
    it 'reuses cached parser results for equivalent profiles' do
      cache = WSDL::Cache.new
      parser_result = instance_double(WSDL::Parser::Result)
      definition_count = 0
      allow(WSDL::Parser::Result).to receive(:new) do
        definition_count += 1
        parser_result
      end

      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: true, strict_schema: false }
      )
      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: true, strict_schema: false }
      )

      expect(definition_count).to eq(1)
      expect(cache.size).to eq(1)
    end

    it 'partitions cache entries by parse-affecting options' do
      cache = WSDL::Cache.new
      parser_result = instance_double(WSDL::Parser::Result)
      definition_count = 0
      allow(WSDL::Parser::Result).to receive(:new) do
        definition_count += 1
        parser_result
      end

      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: true, strict_schema: false }
      )
      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: false, strict_schema: false }
      )

      expect(definition_count).to eq(2)
      expect(cache.size).to eq(2)
    end

    it 'partitions cache entries by strict schema mode' do
      cache = WSDL::Cache.new
      parser_result = instance_double(WSDL::Parser::Result)
      definition_count = 0
      allow(WSDL::Parser::Result).to receive(:new) do
        definition_count += 1
        parser_result
      end

      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: true, strict_schema: false }
      )
      described_class.load(
        wsdl:,
        http: adapter_class.new('shared'),
        cache:,
        parse_options: { sandbox_paths:, limits:, reject_doctype: true, strict_schema: true }
      )

      expect(definition_count).to eq(2)
      expect(cache.size).to eq(2)
    end
  end
end
