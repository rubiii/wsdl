# frozen_string_literal: true

RSpec.describe WSDL::Security::Timestamp do
  describe 'DEFAULT_TTL' do
    it 'is 300 seconds (5 minutes)' do
      expect(described_class::DEFAULT_TTL).to eq(300)
    end
  end

  describe '#initialize' do
    context 'with default options' do
      subject(:timestamp) { described_class.new }

      it 'sets created_at to current UTC time' do
        expect(timestamp.created_at).to be_within(1).of(Time.now.utc)
      end

      it 'sets expires_at to 5 minutes from created_at' do
        expected = timestamp.created_at + 300
        expect(timestamp.expires_at).to be_within(1).of(expected)
      end

      it 'generates a unique ID' do
        expect(timestamp.id).to start_with('Timestamp-')
        expect(timestamp.id).to match(/\ATimestamp-[a-f0-9-]{36}\z/)
      end
    end

    context 'with custom created_at' do
      subject(:timestamp) { described_class.new(created_at: custom_time) }

      let(:custom_time) { Time.utc(2026, 1, 15, 10, 30, 0) }

      it 'uses the provided created_at time' do
        expect(timestamp.created_at).to eq(custom_time)
      end

      it 'calculates expires_at from the provided created_at' do
        expect(timestamp.expires_at).to eq(custom_time + 300)
      end
    end

    context 'with custom expires_in' do
      subject(:timestamp) { described_class.new(expires_in: 600) }

      it 'sets expires_at based on expires_in seconds' do
        expected = timestamp.created_at + 600
        expect(timestamp.expires_at).to eq(expected)
      end
    end

    context 'with explicit expires_at' do
      subject(:timestamp) { described_class.new(created_at: created, expires_at: expires) }

      let(:created) { Time.utc(2026, 1, 15, 10, 30, 0) }
      let(:expires) { Time.utc(2026, 1, 15, 11, 30, 0) }

      it 'uses the explicit expires_at, ignoring expires_in' do
        expect(timestamp.expires_at).to eq(expires)
      end
    end

    context 'with custom id' do
      subject(:timestamp) { described_class.new(id: 'custom-id-123') }

      it 'uses the provided ID' do
        expect(timestamp.id).to eq('custom-id-123')
      end
    end
  end

  describe '#created_at_xml' do
    subject(:timestamp) { described_class.new(created_at: time) }

    let(:time) { Time.utc(2026, 2, 1, 12, 30, 45) }

    it 'returns the created time in XML Schema dateTime format' do
      expect(timestamp.created_at_xml).to eq('2026-02-01T12:30:45Z')
    end
  end

  describe '#expires_at_xml' do
    subject(:timestamp) { described_class.new(created_at: time, expires_in: 300) }

    let(:time) { Time.utc(2026, 2, 1, 12, 30, 45) }

    it 'returns the expiration time in XML Schema dateTime format' do
      expect(timestamp.expires_at_xml).to eq('2026-02-01T12:35:45Z')
    end
  end

  describe '#expired?' do
    context 'when the timestamp has not expired' do
      subject(:timestamp) { described_class.new(expires_in: 3600) }

      it 'returns false' do
        expect(timestamp.expired?).to be false
      end
    end

    context 'when the timestamp has expired' do
      subject(:timestamp) { described_class.new(created_at: past_time, expires_in: 300) }

      let(:past_time) { Time.now.utc - 600 }

      it 'returns true' do
        expect(timestamp.expired?).to be true
      end
    end
  end

  describe '#to_xml' do
    subject(:timestamp) { described_class.new(created_at: time, expires_in: 300, id: 'TS-test-123') }

    let(:time) { Time.utc(2026, 2, 1, 12, 0, 0) }

    it 'builds valid XML with Nokogiri builder' do
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.root('xmlns:wsu' => WSDL::Security::Constants::NS::Security::WSU) do
          timestamp.to_xml(xml)
        end
      end

      doc = builder.doc
      ts_node = doc.at_xpath('//wsu:Timestamp', 'wsu' => WSDL::Security::Constants::NS::Security::WSU)

      expect(ts_node).not_to be_nil
      expect(ts_node['wsu:Id']).to eq('TS-test-123')

      created = ts_node.at_xpath('wsu:Created', 'wsu' => WSDL::Security::Constants::NS::Security::WSU)
      expect(created.text).to eq('2026-02-01T12:00:00Z')

      expires = ts_node.at_xpath('wsu:Expires', 'wsu' => WSDL::Security::Constants::NS::Security::WSU)
      expect(expires.text).to eq('2026-02-01T12:05:00Z')
    end
  end

  describe '#to_hash' do
    subject(:timestamp) { described_class.new(created_at: time, expires_in: 300, id: 'TS-hash-test') }

    let(:time) { Time.utc(2026, 2, 1, 12, 0, 0) }

    it 'returns a hash with wsu:Timestamp structure' do
      hash = timestamp.to_hash

      expect(hash).to have_key('wsu:Timestamp')
      expect(hash['wsu:Timestamp']['wsu:Created']).to eq('2026-02-01T12:00:00Z')
      expect(hash['wsu:Timestamp']['wsu:Expires']).to eq('2026-02-01T12:05:00Z')
    end

    it 'includes the wsu:Id attribute' do
      hash = timestamp.to_hash

      expect(hash['wsu:Timestamp'][:attributes!]).to eq(
        'wsu:Timestamp' => { 'wsu:Id' => 'TS-hash-test' }
      )
    end

    it 'specifies element order' do
      hash = timestamp.to_hash

      expect(hash['wsu:Timestamp'][:order!]).to eq(['wsu:Created', 'wsu:Expires'])
    end
  end

  describe 'unique IDs' do
    it 'generates different IDs for different instances' do
      ts1 = described_class.new
      ts2 = described_class.new

      expect(ts1.id).not_to eq(ts2.id)
    end
  end

  describe 'time zone handling' do
    it 'converts local time to UTC' do
      # Use a time with explicit non-UTC offset
      local_time = Time.new(2026, 2, 1, 12, 0, 0, '+05:00')
      timestamp = described_class.new(created_at: local_time)

      # Should be converted to UTC (12:00 +05:00 = 07:00 UTC)
      expect(timestamp.created_at).to eq(Time.utc(2026, 2, 1, 7, 0, 0))
      expect(timestamp.created_at_xml).to eq('2026-02-01T07:00:00Z')
    end
  end
end
