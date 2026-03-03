# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Builder::Envelope do
  let(:parser_result)  { WSDL::Parser::Result.new fixture('wsdl/temperature'), http_mock }
  let(:operation_info) { parser_result.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }

  let(:header) { nil }
  let(:body) do
    {
      ConvertTemp: {
        Temperature: 30,
        FromUnit: 'degreeCelsius',
        ToUnit: 'degreeFahrenheit'
      }
    }
  end

  describe '#to_s' do
    context 'with pretty_print: true (default)' do
      subject(:envelope) { described_class.new(operation_info, header, body, pretty_print: true) }

      it 'returns XML with indentation' do
        xml = envelope.to_s

        # Pretty printed XML should contain newlines and indentation
        expect(xml).to include("\n")
        expect(xml).to match(/^\s{2,}/) # Has leading whitespace (indentation)
      end

      it 'returns semantically correct XML' do
        expected = Nokogiri.XML(%(
          <env:Envelope
              xmlns:ns0="http://www.webserviceX.NET/"
              xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Header/>
            <env:Body>
              <ns0:ConvertTemp>
                <ns0:Temperature>30</ns0:Temperature>
                <ns0:FromUnit>degreeCelsius</ns0:FromUnit>
                <ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>
              </ns0:ConvertTemp>
            </env:Body>
          </env:Envelope>
        ))

        expect(envelope.to_s)
          .to be_equivalent_to(expected).respecting_element_order
      end
    end

    context 'with pretty_print: false' do
      subject(:envelope) { described_class.new(operation_info, header, body, pretty_print: false) }

      it 'returns compact XML without indentation' do
        xml = envelope.to_s

        # Compact XML should not have leading whitespace on lines
        expect(xml).not_to match(/^\s+</)
        # Should not have newlines with indentation
        expect(xml).not_to match(/\n\s+/)
      end

      it 'returns XML on a single line' do
        xml = envelope.to_s

        # All content should be on one line (no newlines)
        expect(xml.strip).not_to include("\n")
      end

      it 'returns semantically correct XML' do
        expected = Nokogiri.XML(%(
          <env:Envelope
              xmlns:ns0="http://www.webserviceX.NET/"
              xmlns:env="http://www.w3.org/2003/05/soap-envelope">
            <env:Header/>
            <env:Body>
              <ns0:ConvertTemp>
                <ns0:Temperature>30</ns0:Temperature>
                <ns0:FromUnit>degreeCelsius</ns0:FromUnit>
                <ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>
              </ns0:ConvertTemp>
            </env:Body>
          </env:Envelope>
        ))

        expect(envelope.to_s)
          .to be_equivalent_to(expected).respecting_element_order
      end
    end

    context 'default pretty_print value' do
      subject(:envelope) { described_class.new(operation_info, header, body) }

      it 'defaults to pretty_print: true' do
        xml = envelope.to_s

        # Should have indentation by default
        expect(xml).to include("\n")
        expect(xml).to match(/^\s{2,}/)
      end
    end
  end

  describe '#register_namespace' do
    subject(:envelope) { described_class.new(operation_info, header, body) }

    it 'returns a unique namespace ID for each namespace' do
      nsid1 = envelope.register_namespace('http://example.com/ns1')
      nsid2 = envelope.register_namespace('http://example.com/ns2')

      expect(nsid1).to start_with('ns')
      expect(nsid2).to start_with('ns')
      expect(nsid1).not_to eq(nsid2)
    end

    it 'returns the same namespace ID for the same namespace' do
      nsid1 = envelope.register_namespace('http://example.com/ns1')
      nsid2 = envelope.register_namespace('http://example.com/ns1')

      expect(nsid1).to eq(nsid2)
    end
  end

  describe '#require_xsi_namespace' do
    subject(:envelope) { described_class.new(operation_info, header, body) }

    it 'marks the xsi namespace as required' do
      expect(envelope.xsi_required?).to be false

      envelope.require_xsi_namespace

      expect(envelope.xsi_required?).to be true
    end
  end
end
