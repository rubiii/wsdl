# frozen_string_literal: true

RSpec.describe WSDL::Formatting do
  describe '.format_bytes' do
    it 'formats megabytes' do
      expect(described_class.format_bytes(10 * 1024 * 1024)).to eq('10MB')
    end

    it 'formats kilobytes' do
      expect(described_class.format_bytes(512 * 1024)).to eq('512KB')
    end

    it 'formats bytes' do
      expect(described_class.format_bytes(256)).to eq('256B')
    end

    it 'formats zero bytes' do
      expect(described_class.format_bytes(0)).to eq('0B')
    end

    it 'returns unlimited for nil' do
      expect(described_class.format_bytes(nil)).to eq('unlimited')
    end

    it 'formats values at the MB boundary' do
      expect(described_class.format_bytes(1024 * 1024)).to eq('1MB')
    end

    it 'formats values at the KB boundary' do
      expect(described_class.format_bytes(1024)).to eq('1KB')
    end

    it 'truncates partial megabytes' do
      expect(described_class.format_bytes((1024 * 1024) + 512)).to eq('1MB')
    end

    it 'truncates partial kilobytes' do
      expect(described_class.format_bytes(1024 + 512)).to eq('1KB')
    end
  end
end
