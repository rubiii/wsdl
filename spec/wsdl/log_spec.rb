# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Log do
  describe '.root' do
    it 'returns a Logging::Logger' do
      expect(described_class.root).to be_a(Logging::Logger)
    end

    it 'is named WSDL' do
      expect(described_class.root.name).to eq('WSDL')
    end
  end

  describe 'WSDL.logger' do
    it 'delegates to Log.root' do
      expect(WSDL.logger).to equal(described_class.root)
    end
  end
end
