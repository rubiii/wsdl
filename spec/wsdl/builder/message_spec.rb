# frozen_string_literal: true

require 'spec_helper'

describe WSDL::Builder::Message do
  let(:parser_result)  { WSDL::Parser::Result.new fixture('wsdl/temperature'), http_mock }
  let(:operation_info) { parser_result.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }
  let(:envelope)       { WSDL::Builder::Envelope.new(operation_info, nil, nil) }
  let(:parts)          { operation_info.input.body_parts }

  let(:message_data) do
    {
      ConvertTemp: {
        Temperature: 30,
        FromUnit: 'degreeCelsius',
        ToUnit: 'degreeFahrenheit'
      }
    }
  end

  describe '#build' do
    context 'with pretty_print: true (default)' do
      subject(:message) { described_class.new(envelope, parts, pretty_print: true) }

      it 'returns XML with indentation and margin' do
        xml = message.build(message_data)

        # Pretty printed XML should contain newlines and indentation
        expect(xml).to include("\n")
        expect(xml).to match(/^\s{4,}/) # Has margin + indentation (margin: 2, indent: 2)
      end

      it 'returns XML with expected element structure' do
        xml = message.build(message_data)

        # Message builds XML fragments (without namespace declarations)
        # that will be inserted into an Envelope
        expect(xml).to include('<ns0:ConvertTemp>')
        expect(xml).to include('<ns0:Temperature>30</ns0:Temperature>')
        expect(xml).to include('<ns0:FromUnit>degreeCelsius</ns0:FromUnit>')
        expect(xml).to include('<ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>')
        expect(xml).to include('</ns0:ConvertTemp>')
      end
    end

    context 'with pretty_print: false' do
      subject(:message) { described_class.new(envelope, parts, pretty_print: false) }

      it 'returns compact XML without indentation or margin' do
        xml = message.build(message_data)

        # Compact XML should not have leading whitespace
        expect(xml).not_to match(/^\s+</)
        # Should not have newlines with indentation
        expect(xml).not_to match(/\n\s+/)
      end

      it 'returns XML on a single line' do
        xml = message.build(message_data)

        # All content should be on one line (no newlines)
        expect(xml.strip).not_to include("\n")
      end

      it 'returns XML with expected element structure' do
        xml = message.build(message_data)

        # Message builds XML fragments (without namespace declarations)
        # that will be inserted into an Envelope
        expect(xml).to include('<ns0:ConvertTemp>')
        expect(xml).to include('<ns0:Temperature>30</ns0:Temperature>')
        expect(xml).to include('<ns0:FromUnit>degreeCelsius</ns0:FromUnit>')
        expect(xml).to include('<ns0:ToUnit>degreeFahrenheit</ns0:ToUnit>')
        expect(xml).to include('</ns0:ConvertTemp>')
      end
    end

    context 'default pretty_print value' do
      subject(:message) { described_class.new(envelope, parts) }

      it 'defaults to pretty_print: true' do
        xml = message.build(message_data)

        # Should have indentation by default
        expect(xml).to include("\n")
        expect(xml).to match(/^\s{4,}/)
      end
    end

    context 'with invalid attribute keys' do
      subject(:message) { described_class.new(envelope, parts, pretty_print: false) }

      it 'rejects empty attribute names' do
        invalid = {
          ConvertTemp: {
            '_' => 'oops',
            Temperature: 30,
            FromUnit: 'degreeCelsius',
            ToUnit: 'degreeFahrenheit'
          }
        }

        expect {
          message.build(invalid)
        }.to raise_error(ArgumentError, /attribute name cannot be empty/)
      end

      it 'rejects namespace declaration attributes' do
        invalid = {
          ConvertTemp: {
            _xmlns: 'http://evil.example',
            Temperature: 30,
            FromUnit: 'degreeCelsius',
            ToUnit: 'degreeFahrenheit'
          }
        }

        expect {
          message.build(invalid)
        }.to raise_error(ArgumentError, /namespace declarations are not allowed/)
      end
    end
  end
end
