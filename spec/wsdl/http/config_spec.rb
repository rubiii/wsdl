# frozen_string_literal: true

RSpec.describe WSDL::HTTP::Config do
  subject(:config) { described_class.new }

  describe 'secure defaults' do
    it 'uses sensible timeout defaults' do
      expect(config.open_timeout).to eq(WSDL::HTTP::DEFAULT_OPEN_TIMEOUT)
      expect(config.write_timeout).to eq(WSDL::HTTP::DEFAULT_WRITE_TIMEOUT)
      expect(config.read_timeout).to eq(WSDL::HTTP::DEFAULT_READ_TIMEOUT)
    end

    it 'limits redirects by default' do
      expect(config.max_redirects).to eq(WSDL::HTTP::DEFAULT_REDIRECT_LIMIT)
    end

    it 'enforces peer verification by default' do
      expect(config.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'does not set optional SSL options by default' do
      expect(config.ca_file).to be_nil
      expect(config.ca_path).to be_nil
      expect(config.cert).to be_nil
      expect(config.key).to be_nil
      expect(config.min_version).to be_nil
      expect(config.max_version).to be_nil
    end
  end
end
