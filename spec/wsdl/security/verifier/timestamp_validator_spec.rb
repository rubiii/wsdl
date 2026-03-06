# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WSDL::Security::Verifier::TimestampValidator do
  let(:clock_skew) { 300 } # 5 minutes default
  let(:reference_time) { Time.utc(2025, 1, 15, 12, 0, 0) }
  let(:validator) { described_class.new(document, clock_skew:, reference_time:) }
  let(:document) { Nokogiri::XML(xml) }

  def build_timestamp_xml(created: nil, expires: nil, include_timestamp: true)
    timestamp_xml = if include_timestamp
      <<~TIMESTAMP
        <wsu:Timestamp wsu:Id="Timestamp-123">
          #{"<wsu:Created>#{created}</wsu:Created>" if created}
          #{"<wsu:Expires>#{expires}</wsu:Expires>" if expires}
        </wsu:Timestamp>
      TIMESTAMP
    else
      ''
    end

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                     xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <soap:Header>
          <wsse:Security soap:mustUnderstand="1">
            #{timestamp_xml}
          </wsse:Security>
        </soap:Header>
        <soap:Body>
          <Response>OK</Response>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  describe '#valid?' do
    context 'when no timestamp is present' do
      let(:xml) { build_timestamp_xml(include_timestamp: false) }

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'when timestamp is valid' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: '2025-01-15T12:03:00Z'
        )
      end

      it 'returns true' do
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'when timestamp has expired' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:50:00Z',
          expires: '2025-01-15T11:54:00Z' # 6 minutes ago (beyond 5min skew)
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports expiration error' do
        validator.valid?
        expect(validator.errors).to include(match(/Timestamp has expired/))
      end

      it 'includes how long ago it expired' do
        validator.valid?
        expect(validator.errors.first).to include('360s ago')
      end
    end

    context 'when timestamp expires exactly at clock skew boundary' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:50:00Z',
          expires: '2025-01-15T11:55:00Z' # exactly 5 minutes ago
        )
      end

      it 'returns true (boundary is inclusive)' do
        expect(validator.valid?).to be true
      end
    end

    context 'when Created is too far in the future' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T12:06:00Z', # 6 minutes ahead (beyond 5min skew)
          expires: '2025-01-15T12:11:00Z'
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports future timestamp error' do
        validator.valid?
        expect(validator.errors).to include(match(/Created is too far in the future/))
      end

      it 'includes how far ahead it is' do
        validator.valid?
        expect(validator.errors.first).to include('360s ahead')
      end
    end

    context 'when Created is exactly at clock skew boundary' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T12:05:00Z', # exactly 5 minutes ahead
          expires: '2025-01-15T12:10:00Z'
        )
      end

      it 'returns true (boundary is inclusive)' do
        expect(validator.valid?).to be true
      end
    end

    context 'when only Created is present' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: nil
        )
      end

      it 'returns true' do
        expect(validator.valid?).to be true
      end
    end

    context 'when only Expires is present' do
      let(:xml) do
        build_timestamp_xml(
          created: nil,
          expires: '2025-01-15T12:03:00Z'
        )
      end

      it 'returns true' do
        expect(validator.valid?).to be true
      end
    end

    context 'when timestamp has neither Created nor Expires' do
      let(:xml) do
        build_timestamp_xml(
          created: nil,
          expires: nil
        )
      end

      it 'returns true' do
        expect(validator.valid?).to be true
      end
    end

    context 'when Created has malformed value' do
      let(:xml) do
        build_timestamp_xml(
          created: 'not-a-valid-time',
          expires: '2025-01-15T12:03:00Z'
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports invalid Created format' do
        validator.valid?
        expect(validator.errors).to include(match(/Timestamp Created must be a valid UTC xsd:dateTime/))
      end

      it 'sets created_at to nil' do
        validator.valid?
        expect(validator.created_at).to be_nil
      end
    end

    context 'when Expires has malformed value' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: 'invalid-time'
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports invalid Expires format' do
        validator.valid?
        expect(validator.errors).to include(match(/Timestamp Expires must be a valid UTC xsd:dateTime/))
      end

      it 'sets expires_at to nil' do
        validator.valid?
        expect(validator.expires_at).to be_nil
      end
    end

    context 'when Created and Expires are both malformed' do
      let(:xml) do
        build_timestamp_xml(
          created: 'not-a-valid-time',
          expires: 'still-not-a-valid-time'
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports both invalid timestamp fields' do
        validator.valid?
        expect(validator.errors).to include(match(/Timestamp Created must be a valid UTC xsd:dateTime/))
        expect(validator.errors).to include(match(/Timestamp Expires must be a valid UTC xsd:dateTime/))
      end
    end
  end

  describe '#timestamp_present?' do
    context 'when timestamp exists' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: '2025-01-15T12:03:00Z'
        )
      end

      it 'returns true' do
        expect(validator.timestamp_present?).to be true
      end
    end

    context 'when timestamp does not exist' do
      let(:xml) { build_timestamp_xml(include_timestamp: false) }

      it 'returns false' do
        expect(validator.timestamp_present?).to be false
      end
    end

    context 'when timestamp is outside Security header' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <soap:Header>
              <wsu:Timestamp wsu:Id="Timestamp-outside">
                <wsu:Created>2025-01-15T11:58:00Z</wsu:Created>
                <wsu:Expires>2025-01-15T12:03:00Z</wsu:Expires>
              </wsu:Timestamp>
              <wsse:Security soap:mustUnderstand="1">
              </wsse:Security>
            </soap:Header>
            <soap:Body>
              <Response>OK</Response>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns false' do
        expect(validator.timestamp_present?).to be false
      end
    end
  end

  describe '#timestamp' do
    context 'when timestamp exists with both Created and Expires' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: '2025-01-15T12:03:00Z'
        )
      end

      it 'returns a hash with created_at and expires_at' do
        result = validator.timestamp
        expect(result).to be_a(Hash)
        expect(result).to have_key(:created_at)
        expect(result).to have_key(:expires_at)
      end

      it 'parses created_at as UTC Time' do
        result = validator.timestamp
        expect(result[:created_at]).to eq(Time.utc(2025, 1, 15, 11, 58, 0))
      end

      it 'parses expires_at as UTC Time' do
        result = validator.timestamp
        expect(result[:expires_at]).to eq(Time.utc(2025, 1, 15, 12, 3, 0))
      end
    end

    context 'when only Created is present' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00Z',
          expires: nil
        )
      end

      it 'returns hash with nil expires_at' do
        result = validator.timestamp
        expect(result[:created_at]).to eq(Time.utc(2025, 1, 15, 11, 58, 0))
        expect(result[:expires_at]).to be_nil
      end
    end

    context 'when no timestamp exists' do
      let(:xml) { build_timestamp_xml(include_timestamp: false) }

      it 'returns nil' do
        expect(validator.timestamp).to be_nil
      end
    end
  end

  describe '#created_at' do
    let(:xml) do
      build_timestamp_xml(
        created: '2025-01-15T11:58:30Z',
        expires: '2025-01-15T12:03:00Z'
      )
    end

    it 'returns the parsed Created time' do
      validator.valid?
      expect(validator.created_at).to be_a(Time)
      expect(validator.created_at).to eq(Time.utc(2025, 1, 15, 11, 58, 30))
    end

    it 'returns UTC time' do
      validator.valid?
      expect(validator.created_at.utc?).to be true
    end
  end

  describe '#expires_at' do
    let(:xml) do
      build_timestamp_xml(
        created: '2025-01-15T11:58:00Z',
        expires: '2025-01-15T12:03:30Z'
      )
    end

    it 'returns the parsed Expires time' do
      validator.valid?
      expect(validator.expires_at).to be_a(Time)
      expect(validator.expires_at).to eq(Time.utc(2025, 1, 15, 12, 3, 30))
    end

    it 'returns UTC time' do
      validator.valid?
      expect(validator.expires_at.utc?).to be true
    end
  end

  describe 'clock_skew configuration' do
    let(:xml) do
      build_timestamp_xml(
        created: '2025-01-15T12:08:00Z', # 8 minutes ahead
        expires: '2025-01-15T12:13:00Z'
      )
    end

    context 'with default clock_skew (300 seconds)' do
      it 'rejects timestamps more than 5 minutes ahead' do
        expect(validator.valid?).to be false
      end
    end

    context 'with increased clock_skew (600 seconds)' do
      let(:clock_skew) { 600 }

      it 'accepts timestamps within 10 minutes' do
        expect(validator.valid?).to be true
      end
    end

    context 'with very small clock_skew (60 seconds)' do
      let(:clock_skew) { 60 }

      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T12:01:30Z', # 90 seconds ahead
          expires: '2025-01-15T12:06:00Z'
        )
      end

      it 'rejects timestamps more than 1 minute ahead' do
        expect(validator.valid?).to be false
      end
    end

    context 'with zero clock_skew' do
      let(:clock_skew) { 0 }

      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T12:00:01Z', # 1 second ahead
          expires: '2025-01-15T12:05:00Z'
        )
      end

      it 'rejects any future timestamps' do
        expect(validator.valid?).to be false
      end
    end
  end

  describe 'reference_time configuration' do
    let(:xml) do
      build_timestamp_xml(
        created: '2025-01-15T11:58:00Z',
        expires: '2025-01-15T12:03:00Z'
      )
    end

    context 'with explicit reference_time' do
      let(:reference_time) { Time.utc(2025, 1, 15, 12, 0, 0) }

      it 'uses the provided reference time for validation' do
        expect(validator.valid?).to be true
      end
    end

    context 'with reference_time after expires (beyond skew)' do
      let(:reference_time) { Time.utc(2025, 1, 15, 12, 10, 0) } # 7 minutes after expires

      it 'returns false' do
        expect(validator.valid?).to be false
      end
    end

    context 'without explicit reference_time' do
      let(:validator) { described_class.new(document, clock_skew:) }

      it 'uses current time' do
        # Create a timestamp that would be valid now
        allow(Time).to receive(:now).and_return(Time.utc(2025, 1, 15, 12, 0, 0))
        expect(validator.valid?).to be true
      end
    end
  end

  describe 'DEFAULT_CLOCK_SKEW constant' do
    it 'is 300 seconds (5 minutes)' do
      expect(described_class::DEFAULT_CLOCK_SKEW).to eq(300)
    end
  end

  describe 'timezone handling' do
    context 'with UTC zero-offset timezone' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00+00:00',
          expires: '2025-01-15T12:03:00+00:00'
        )
      end

      it 'validates successfully' do
        expect(validator.valid?).to be true
      end

      it 'stores times as UTC' do
        validator.valid?
        expect(validator.created_at.utc?).to be true
        expect(validator.created_at).to eq(Time.utc(2025, 1, 15, 11, 58, 0))
      end
    end

    context 'with non-UTC timezone offset' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T06:58:00-05:00',
          expires: '2025-01-15T07:03:00-05:00'
        )
      end

      it 'returns false' do
        expect(validator.valid?).to be false
      end

      it 'reports invalid UTC requirement for both fields' do
        validator.valid?
        expect(validator.errors).to include(match(/Timestamp Created must be a valid UTC xsd:dateTime/))
        expect(validator.errors).to include(match(/Timestamp Expires must be a valid UTC xsd:dateTime/))
      end
    end
  end

  describe 'SOAP 1.2 compatibility' do
    let(:xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
          <soap12:Header>
            <wsse:Security soap12:mustUnderstand="true">
              <wsu:Timestamp wsu:Id="Timestamp-123">
                <wsu:Created>2025-01-15T11:58:00Z</wsu:Created>
                <wsu:Expires>2025-01-15T12:03:00Z</wsu:Expires>
              </wsu:Timestamp>
            </wsse:Security>
          </soap12:Header>
          <soap12:Body>
            <Response>OK</Response>
          </soap12:Body>
        </soap12:Envelope>
      XML
    end

    it 'finds timestamp in SOAP 1.2 messages' do
      expect(validator.timestamp_present?).to be true
    end

    it 'validates SOAP 1.2 timestamps correctly' do
      expect(validator.valid?).to be true
    end
  end

  describe 'edge cases' do
    context 'with subsecond precision in timestamps' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-01-15T11:58:00.123456789Z',
          expires: '2025-01-15T12:03:00.987654321Z'
        )
      end

      it 'handles nanosecond precision' do
        expect(validator.valid?).to be true
        expect(validator.created_at.nsec).to be > 0
      end
    end

    context 'with empty Security header' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                         xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <soap:Header>
              <wsse:Security soap:mustUnderstand="1"/>
            </soap:Header>
            <soap:Body>
              <Response>OK</Response>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns no timestamp present' do
        expect(validator.timestamp_present?).to be false
      end

      it 'validates successfully' do
        expect(validator.valid?).to be true
      end
    end

    context 'with no Security header at all' do
      let(:xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Header/>
            <soap:Body>
              <Response>OK</Response>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      it 'returns no timestamp present' do
        expect(validator.timestamp_present?).to be false
      end

      it 'validates successfully' do
        expect(validator.valid?).to be true
      end
    end

    context 'with Created matching timezone regex but failing iso8601 parse' do
      let(:xml) do
        build_timestamp_xml(
          created: '2025-13-01T00:00:00Z',
          expires: '2025-01-15T12:05:00Z'
        )
      end

      it 'returns false for unparseable date' do
        expect(validator.valid?).to be false
      end

      it 'reports invalid time value' do
        validator.valid?
        expect(validator.errors.join).to match(/Created.*valid/)
      end
    end
  end
end
