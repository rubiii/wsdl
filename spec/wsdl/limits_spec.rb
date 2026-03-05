# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Limits do
  subject(:limits) { described_class.new }

  describe '.new' do
    it 'creates a frozen instance' do
      expect(limits).to be_frozen
    end

    context 'with default values' do
      it 'sets max_document_size to 10 MB' do
        expect(limits.max_document_size).to eq(10 * 1024 * 1024)
      end

      it 'sets max_total_download_size to 50 MB' do
        expect(limits.max_total_download_size).to eq(50 * 1024 * 1024)
      end

      it 'sets max_schemas to 50' do
        expect(limits.max_schemas).to eq(50)
      end

      it 'sets max_elements_per_type to 500' do
        expect(limits.max_elements_per_type).to eq(500)
      end

      it 'sets max_attributes_per_element to 100' do
        expect(limits.max_attributes_per_element).to eq(100)
      end

      it 'sets max_type_nesting_depth to 50' do
        expect(limits.max_type_nesting_depth).to eq(50)
      end

      it 'sets max_schema_import_iterations to 100' do
        expect(limits.max_schema_import_iterations).to eq(100)
      end

      it 'sets max_response_size to 10 MB' do
        expect(limits.max_response_size).to eq(10 * 1024 * 1024)
      end
    end

    context 'with custom values' do
      subject(:limits) do
        described_class.new(
          max_document_size: 5 * 1024 * 1024,
          max_total_download_size: 25 * 1024 * 1024,
          max_schemas: 100,
          max_elements_per_type: 1000,
          max_attributes_per_element: 200,
          max_type_nesting_depth: 100,
          max_schema_import_iterations: 200,
          max_response_size: 5 * 1024 * 1024
        )
      end

      it 'uses the custom max_document_size' do
        expect(limits.max_document_size).to eq(5 * 1024 * 1024)
      end

      it 'uses the custom max_total_download_size' do
        expect(limits.max_total_download_size).to eq(25 * 1024 * 1024)
      end

      it 'uses the custom max_schemas' do
        expect(limits.max_schemas).to eq(100)
      end

      it 'uses the custom max_elements_per_type' do
        expect(limits.max_elements_per_type).to eq(1000)
      end

      it 'uses the custom max_attributes_per_element' do
        expect(limits.max_attributes_per_element).to eq(200)
      end

      it 'uses the custom max_type_nesting_depth' do
        expect(limits.max_type_nesting_depth).to eq(100)
      end

      it 'uses the custom max_schema_import_iterations' do
        expect(limits.max_schema_import_iterations).to eq(200)
      end

      it 'uses the custom max_response_size' do
        expect(limits.max_response_size).to eq(5 * 1024 * 1024)
      end
    end

    context 'with nil values (disabled limits)' do
      subject(:limits) do
        described_class.new(
          max_document_size: nil,
          max_total_download_size: nil,
          max_schemas: nil,
          max_elements_per_type: nil,
          max_attributes_per_element: nil,
          max_type_nesting_depth: nil,
          max_schema_import_iterations: nil,
          max_response_size: nil
        )
      end

      it 'allows nil for max_document_size' do
        expect(limits.max_document_size).to be_nil
      end

      it 'allows nil for max_total_download_size' do
        expect(limits.max_total_download_size).to be_nil
      end

      it 'allows nil for max_schemas' do
        expect(limits.max_schemas).to be_nil
      end

      it 'allows nil for max_elements_per_type' do
        expect(limits.max_elements_per_type).to be_nil
      end

      it 'allows nil for max_attributes_per_element' do
        expect(limits.max_attributes_per_element).to be_nil
      end

      it 'allows nil for max_type_nesting_depth' do
        expect(limits.max_type_nesting_depth).to be_nil
      end

      it 'allows nil for max_schema_import_iterations' do
        expect(limits.max_schema_import_iterations).to be_nil
      end

      it 'allows nil for max_response_size' do
        expect(limits.max_response_size).to be_nil
      end
    end
  end

  describe '#with' do
    it 'returns a new Limits instance' do
      new_limits = limits.with(max_schemas: 100)
      expect(new_limits).to be_a(described_class)
      expect(new_limits).not_to eq(limits)
    end

    it 'creates a frozen instance' do
      new_limits = limits.with(max_schemas: 100)
      expect(new_limits).to be_frozen
    end

    it 'overrides the specified value' do
      new_limits = limits.with(max_schemas: 200)
      expect(new_limits.max_schemas).to eq(200)
    end

    it 'preserves other values' do
      new_limits = limits.with(max_schemas: 200)
      expect(new_limits.max_document_size).to eq(limits.max_document_size)
      expect(new_limits.max_total_download_size).to eq(limits.max_total_download_size)
      expect(new_limits.max_elements_per_type).to eq(limits.max_elements_per_type)
      expect(new_limits.max_attributes_per_element).to eq(limits.max_attributes_per_element)
      expect(new_limits.max_type_nesting_depth).to eq(limits.max_type_nesting_depth)
    end

    it 'allows overriding multiple values' do
      new_limits = limits.with(
        max_document_size: 20 * 1024 * 1024,
        max_schemas: 100,
        max_type_nesting_depth: 100
      )

      expect(new_limits.max_document_size).to eq(20 * 1024 * 1024)
      expect(new_limits.max_schemas).to eq(100)
      expect(new_limits.max_type_nesting_depth).to eq(100)
    end

    it 'allows disabling a limit by setting it to nil' do
      new_limits = limits.with(max_schemas: nil)
      expect(new_limits.max_schemas).to be_nil
    end

    it 'does not modify the original instance' do
      original_max_schemas = limits.max_schemas
      limits.with(max_schemas: 999)
      expect(limits.max_schemas).to eq(original_max_schemas)
    end
  end

  describe '#to_h' do
    it 'returns a hash with all limit values' do
      expect(limits.to_h).to eq(
        max_document_size: 10 * 1024 * 1024,
        max_total_download_size: 50 * 1024 * 1024,
        max_schemas: 50,
        max_elements_per_type: 500,
        max_attributes_per_element: 100,
        max_type_nesting_depth: 50,
        max_request_elements: 10_000,
        max_request_depth: 100,
        max_request_attributes: 1_000,
        max_schema_import_iterations: 100,
        max_response_size: 10 * 1024 * 1024
      )
    end

    it 'includes nil values for disabled limits' do
      limits_with_nil = described_class.new(max_schemas: nil)
      expect(limits_with_nil.to_h[:max_schemas]).to be_nil
    end
  end

  describe '#inspect' do
    it 'returns a human-readable string' do
      expect(limits.inspect).to include('WSDL::Limits')
      expect(limits.inspect).to include('max_document_size=10MB')
      expect(limits.inspect).to include('max_total_download_size=50MB')
      expect(limits.inspect).to include('max_schemas=50')
    end

    it 'formats KB values correctly' do
      kb_limits = described_class.new(max_document_size: 512 * 1024)
      expect(kb_limits.inspect).to include('max_document_size=512KB')
    end

    it 'formats byte values correctly' do
      byte_limits = described_class.new(max_document_size: 512)
      expect(byte_limits.inspect).to include('max_document_size=512B')
    end

    it 'shows unlimited for nil values' do
      unlimited = described_class.new(max_schemas: nil, max_document_size: nil)
      expect(unlimited.inspect).to include('max_schemas=unlimited')
      expect(unlimited.inspect).to include('max_document_size=unlimited')
    end
  end

  describe '#==' do
    it 'returns true for instances with the same values' do
      limits1 = described_class.new
      limits2 = described_class.new

      expect(limits1 == limits2).to be(true)
    end

    it 'returns false for instances with different values' do
      limits1 = described_class.new
      limits2 = described_class.new(max_schemas: 100)

      expect(limits1 == limits2).to be(false)
    end

    it 'returns false when compared to non-Limits objects' do
      expect(limits == 'not a limits').to be(false)
      expect(limits.nil?).to be(false)
      expect(limits == limits.to_h).to be(false)
    end
  end

  describe '#eql?' do
    it 'is an alias for ==' do
      limits1 = described_class.new
      limits2 = described_class.new

      expect(limits1.eql?(limits2)).to be(true)
    end
  end

  describe '#hash' do
    it 'returns the same hash for equal instances' do
      limits1 = described_class.new
      limits2 = described_class.new

      expect(limits1.hash).to eq(limits2.hash)
    end

    it 'returns different hashes for different instances' do
      limits1 = described_class.new
      limits2 = described_class.new(max_schemas: 100)

      expect(limits1.hash).not_to eq(limits2.hash)
    end

    it 'allows Limits to be used as Hash keys' do
      hash = {}
      hash[described_class.new] = :value1
      hash[described_class.new] = :value2

      expect(hash.size).to eq(1)
      expect(hash[described_class.new]).to eq(:value2)
    end
  end

  describe 'global accessor' do
    after do
      # Reset to default after each test
      WSDL.limits = nil
    end

    describe 'WSDL.limits' do
      it 'returns a default Limits instance' do
        expect(WSDL.limits).to be_a(described_class)
      end

      it 'returns the same instance on subsequent calls' do
        first_call = WSDL.limits
        second_call = WSDL.limits
        expect(first_call).to equal(second_call)
      end
    end

    describe 'WSDL.limits=' do
      it 'allows setting a custom Limits instance' do
        custom = described_class.new(max_schemas: 200)
        WSDL.limits = custom

        expect(WSDL.limits).to eq(custom)
      end

      it 'resets to default when set to nil' do
        custom = described_class.new(max_schemas: 200)
        WSDL.limits = custom
        WSDL.limits = nil

        # Next call should create a new default instance
        expect(WSDL.limits.max_schemas).to eq(50)
      end
    end
  end

  describe 'constants' do
    it 'defines DEFAULT_MAX_DOCUMENT_SIZE as 10 MB' do
      expect(described_class::DEFAULT_MAX_DOCUMENT_SIZE).to eq(10 * 1024 * 1024)
    end

    it 'defines DEFAULT_MAX_TOTAL_DOWNLOAD_SIZE as 50 MB' do
      expect(described_class::DEFAULT_MAX_TOTAL_DOWNLOAD_SIZE).to eq(50 * 1024 * 1024)
    end

    it 'defines DEFAULT_MAX_SCHEMAS as 50' do
      expect(described_class::DEFAULT_MAX_SCHEMAS).to eq(50)
    end

    it 'defines DEFAULT_MAX_ELEMENTS_PER_TYPE as 500' do
      expect(described_class::DEFAULT_MAX_ELEMENTS_PER_TYPE).to eq(500)
    end

    it 'defines DEFAULT_MAX_ATTRIBUTES_PER_ELEMENT as 100' do
      expect(described_class::DEFAULT_MAX_ATTRIBUTES_PER_ELEMENT).to eq(100)
    end

    it 'defines DEFAULT_MAX_TYPE_NESTING_DEPTH as 50' do
      expect(described_class::DEFAULT_MAX_TYPE_NESTING_DEPTH).to eq(50)
    end

    it 'defines DEFAULT_MAX_SCHEMA_IMPORT_ITERATIONS as 100' do
      expect(described_class::DEFAULT_MAX_SCHEMA_IMPORT_ITERATIONS).to eq(100)
    end

    it 'defines DEFAULT_MAX_RESPONSE_SIZE as 10 MB' do
      expect(described_class::DEFAULT_MAX_RESPONSE_SIZE).to eq(10 * 1024 * 1024)
    end
  end
end
