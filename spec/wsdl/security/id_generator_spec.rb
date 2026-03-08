# frozen_string_literal: true

RSpec.describe WSDL::Security::IdGenerator do
  describe '.for' do
    it 'generates an ID with the given prefix' do
      id = described_class.for('Timestamp')
      expect(id).to start_with('Timestamp-')
    end

    it 'generates a UUID-formatted suffix' do
      id = described_class.for('Test')
      # UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
      expect(id).to match(/\ATest-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/)
    end

    it 'generates unique IDs on each call' do
      ids = Array.new(100) { described_class.for('Test') }
      expect(ids.uniq.size).to eq(100)
    end

    it 'works with various prefixes' do
      prefixes = %w[Timestamp UsernameToken SecurityToken Body Header Action]

      prefixes.each do |prefix|
        id = described_class.for(prefix)
        expect(id).to start_with("#{prefix}-")
      end
    end

    it 'handles empty prefix' do
      id = described_class.for('')
      expect(id).to match(/\A-[a-f0-9-]{36}\z/)
    end

    it 'handles special characters in prefix' do
      id = described_class.for('My-Special_Prefix')
      expect(id).to start_with('My-Special_Prefix-')
    end
  end
end
