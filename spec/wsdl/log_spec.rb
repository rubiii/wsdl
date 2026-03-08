# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Log do
  describe 'WSDL.logger' do
    it 'defaults to a NullLogger' do
      WSDL.logger = nil
      expect(WSDL.logger).to be_a(WSDL::Log::NullLogger)
    end

    it 'can be set to a custom logger' do
      custom = Logger.new(StringIO.new)
      WSDL.logger = custom
      expect(WSDL.logger).to equal(custom)
    end
  end

  describe '#logger' do
    it 'delegates to WSDL.logger' do
      obj = Class.new { include WSDL::Log }.new
      expect(obj.logger).to equal(WSDL.logger)
    end
  end

  describe '.logger (class-level)' do
    it 'delegates to WSDL.logger' do
      klass = Class.new { include WSDL::Log }
      expect(klass.logger).to equal(WSDL.logger)
    end
  end
end
