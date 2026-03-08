# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL do
  describe '.http_adapter' do
    after do
      # reset global state!
      described_class.http_adapter = nil
    end

    it 'returns the default HTTP adapter class' do
      expect(described_class.http_adapter).to eq(WSDL::HTTPAdapter)
    end

    it 'can be changed to use a custom adapter' do
      adapter_class = Class.new do
        def cache_key
          'custom-adapter'
        end

        def config
          'http-config'
        end
      end

      described_class.http_adapter = adapter_class
      expect(described_class.http_adapter).to eq(adapter_class)

      client = WSDL::Client.new(fixture('wsdl/amazon'))
      expect(client.http).to eq('http-config')
    end
  end

  describe '.cache' do
    after do
      # reset global state!
      described_class.cache = nil
    end

    it 'returns a default Cache instance when not nil' do
      described_class.cache = WSDL::Cache.new
      expect(described_class.cache).to be_an_instance_of(WSDL::Cache)
    end

    it 'returns the same instance on subsequent calls' do
      described_class.cache = WSDL::Cache.new
      first_call = described_class.cache
      second_call = described_class.cache
      expect(first_call).to be(second_call)
    end

    it 'can be changed to use a custom cache' do
      custom_cache = WSDL::Cache.new(ttl: 3600)

      described_class.cache = custom_cache
      expect(described_class.cache).to be(custom_cache)
    end

    it 'returns nil when set to nil' do
      described_class.cache = nil
      expect(described_class.cache).to be_nil
    end
  end
end
