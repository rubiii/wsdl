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

  def load_cached(**overrides)
    described_class.load(
      wsdl: overrides.fetch(:wsdl, wsdl),
      http: overrides.fetch(:http, adapter_class.new('shared')),
      cache: overrides.fetch(:cache, WSDL::Cache.new),
      sandbox_paths: overrides.fetch(:sandbox_paths, sandbox_paths),
      limits: overrides.fetch(:limits, limits),
      reject_doctype: overrides.fetch(:reject_doctype, true),
      strict_schema: overrides.fetch(:strict_schema, false)
    )
  end

  # Stubs Result.new, yields a counter proc, and returns the cache.
  # Usage:
  #   cache, count = stub_result
  #   load_cached(cache:)
  #   expect(count.call).to eq(1)
  def stub_result
    parser_result = instance_double(WSDL::Parser::Result)
    definition_count = 0

    allow(WSDL::Parser::Result).to receive(:new) do
      definition_count += 1
      parser_result
    end

    cache = WSDL::Cache.new
    [cache, -> { definition_count }]
  end

  describe 'ParseInputs' do
    subject(:parse_inputs) { described_class::ParseInputs }

    it 'is a Data class with the expected members' do
      expect(parse_inputs.members).to contain_exactly(:wsdl, :http, :sandbox_paths, :limits, :reject_doctype,
                                                      :strict_schema)
    end

    it 'has exactly 6 members (bump this when adding a new parse-affecting parameter)' do
      # If this fails, you added a member to ParseInputs. Great! Now also:
      # 1. Add its normalization to CachedResult.cache_key
      # 2. Pass it through in CachedResult.build_result
      # 3. Add a "partitions by <member>" test below
      # 4. Update this count
      expect(parse_inputs.members.size).to eq(6)
    end

    it 'requires all members at construction time' do
      expect {
        parse_inputs.new(wsdl:, http: adapter_class.new('x'))
      }.to raise_error(ArgumentError)
    end

    it 'is frozen after construction' do
      inputs = parse_inputs.new(
        wsdl:,
        http: adapter_class.new('x'),
        sandbox_paths:,
        limits:,
        reject_doctype: true,
        strict_schema: false
      )

      expect(inputs).to be_frozen
    end
  end

  describe '.load' do
    context 'without cache' do
      it 'bypasses the cache when cache is nil' do
        parser_result = instance_double(WSDL::Parser::Result)
        allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

        result = load_cached(cache: nil)

        expect(result).to eq(parser_result)
      end

      it 'resolves :default to WSDL.cache' do
        cache, count = stub_result

        allow(WSDL).to receive(:cache).and_return(cache)

        load_cached(cache: :default)
        load_cached(cache: :default)

        expect(count.call).to eq(1)
      end
    end

    context 'cache hit / miss' do
      it 'reuses cached parser results for equivalent inputs' do
        cache, count = stub_result

        load_cached(cache:)
        load_cached(cache:)

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end

      it 'passes all inputs to Result.new' do
        http = adapter_class.new('adapter-1')
        parser_result = instance_double(WSDL::Parser::Result)

        allow(WSDL::Parser::Result).to receive(:new).and_return(parser_result)

        # Use cache: nil to force Result.new every time (no caching)
        result = load_cached(cache: nil, http:, reject_doctype: false, strict_schema: true)

        expect(result).to eq(parser_result)
        expect(WSDL::Parser::Result).to have_received(:new).with(
          wsdl,
          http,
          sandbox_paths:,
          limits:,
          reject_doctype: false,
          strict_schema: true
        )
      end
    end

    context 'cache key partitioning' do
      it 'partitions by reject_doctype' do
        cache, count = stub_result

        load_cached(cache:, reject_doctype: true)
        load_cached(cache:, reject_doctype: false)

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'partitions by strict_schema' do
        cache, count = stub_result

        load_cached(cache:, strict_schema: false)
        load_cached(cache:, strict_schema: true)

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'partitions by HTTP adapter cache_key' do
        cache, count = stub_result

        load_cached(cache:, http: adapter_class.new('adapter-a'))
        load_cached(cache:, http: adapter_class.new('adapter-b'))

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'shares cache entries for identical HTTP adapter cache_keys' do
        cache, count = stub_result

        load_cached(cache:, http: adapter_class.new('same'))
        load_cached(cache:, http: adapter_class.new('same'))

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end

      it 'partitions by sandbox_paths' do
        cache, count = stub_result

        load_cached(cache:, sandbox_paths: ['/path/a'])
        load_cached(cache:, sandbox_paths: ['/path/b'])

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'partitions by sandbox_paths presence (nil vs array)' do
        cache, count = stub_result

        load_cached(cache:, sandbox_paths: nil)
        load_cached(cache:, sandbox_paths: ['/some/path'])

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'partitions by limits' do
        cache, count = stub_result

        limits_a = WSDL::Limits.new(max_schemas: 10)
        limits_b = WSDL::Limits.new(max_schemas: 20)

        load_cached(cache:, limits: limits_a)
        load_cached(cache:, limits: limits_b)

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end

      it 'shares cache entries for equivalent limits' do
        cache, count = stub_result

        load_cached(cache:, limits: WSDL::Limits.new)
        load_cached(cache:, limits: WSDL::Limits.new)

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end

      it 'partitions by WSDL source' do
        cache, count = stub_result

        wsdl_a = fixture('wsdl/amazon')
        wsdl_b = fixture('wsdl/authentication')

        load_cached(cache:, wsdl: wsdl_a, sandbox_paths: [File.dirname(File.expand_path(wsdl_a))])
        load_cached(cache:, wsdl: wsdl_b, sandbox_paths: [File.dirname(File.expand_path(wsdl_b))])

        expect(count.call).to eq(2)
        expect(cache.size).to eq(2)
      end
    end

    context 'sandbox path normalization' do
      it 'normalizes sandbox paths so equivalent paths share cache entries' do
        cache, count = stub_result

        dir = File.dirname(File.expand_path(wsdl))
        relative_dir = File.join(dir, 'subdir', '..')

        load_cached(cache:, sandbox_paths: [dir])
        load_cached(cache:, sandbox_paths: [relative_dir])

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end

      it 'deduplicates sandbox paths' do
        cache, count = stub_result

        dir = File.dirname(File.expand_path(wsdl))

        load_cached(cache:, sandbox_paths: [dir])
        load_cached(cache:, sandbox_paths: [dir, dir])

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end

      it 'sorts sandbox paths so order does not matter' do
        cache, count = stub_result

        load_cached(cache:, sandbox_paths: ['/path/a', '/path/b'])
        load_cached(cache:, sandbox_paths: ['/path/b', '/path/a'])

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end
    end

    context 'when all inputs are identical' do
      it 'never re-parses regardless of how many times load is called' do
        cache, count = stub_result

        http = adapter_class.new('stable')

        10.times do
          load_cached(cache:, http:)
        end

        expect(count.call).to eq(1)
        expect(cache.size).to eq(1)
      end
    end
  end
end
