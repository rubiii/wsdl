# frozen_string_literal: true

# rubocop:disable Style/MultilineBlockChain

require 'rantly'
require 'rantly/rspec_extensions'
require 'tempfile'

# Fuzz testing for the WSDL parsing pipeline.
#
# Invariant: Client.new should never crash with an unhandled exception.
# It should either parse successfully or raise a WSDL::Error subclass.
# Internal errors like NoMethodError, TypeError, or KeyError indicate bugs.

RSpec.describe 'WSDL parser resilience' do
  let(:trial_count) { Integer(ENV.fetch('PROPERTY_TRIALS', 100)) }

  def parse_wsdl(content)
    file = Tempfile.new(['fuzz', '.wsdl'])
    file.write(content)
    file.close
    client = WSDL::Client.new(file.path)
    client.services
    :parsed
  rescue WSDL::Error
    :expected_error
  ensure
    file.unlink
  end

  describe 'invariant: truncated WSDLs never crash' do
    it 'handles truncation at random byte offsets' do
      wsdl_content = File.read(SpecSupport::Fixture.path('wsdl/blz_service'))

      property_of {
        offset = range(0, wsdl_content.bytesize)
        wsdl_content.byteslice(0, offset)
      }.check(trial_count) do |truncated|
        result = parse_wsdl(truncated)
        expect(result).to eq(:parsed).or eq(:expected_error)
      end
    end
  end

  describe 'invariant: random WSDL-like XML never crashes' do
    it 'handles random elements in WSDL namespace' do
      property_of {
        wsdl_ns = 'http://schemas.xmlsoap.org/wsdl/'
        soap_ns = 'http://schemas.xmlsoap.org/wsdl/soap/'
        xsd_ns = 'http://www.w3.org/2001/XMLSchema'
        tns = "http://#{sized(range(3, 10)) { string(:alpha) }}.com"

        elements = %w[types message portType binding service operation input output fault part]
        children = Array.new(range(1, 5)) {
          tag = choose(*elements)
          name = sized(range(3, 10)) { string(:alpha) }
          "<wsdl:#{tag} name=\"#{name}\"/>"
        }.join("\n    ")

        <<~XML
          <wsdl:definitions xmlns:wsdl="#{wsdl_ns}" xmlns:soap="#{soap_ns}"
                            xmlns:xsd="#{xsd_ns}" xmlns:tns="#{tns}"
                            targetNamespace="#{tns}">
            #{children}
          </wsdl:definitions>
        XML
      }.check(trial_count) do |xml|
        result = parse_wsdl(xml)
        expect(result).to eq(:parsed).or eq(:expected_error)
      end
    end

    it 'handles random schema types with random nesting' do
      property_of {
        tns = "http://#{sized(range(3, 8)) { string(:alpha) }}.com"
        xsd_types = %w[string int boolean decimal float double date dateTime]

        type_defs = Array.new(range(1, 3)) {
          name = sized(range(3, 8)) { string(:alpha) }
          xsd_type = choose(*xsd_types)
          if boolean
            "<xsd:element name=\"#{name}\" type=\"xsd:#{xsd_type}\"/>"
          else
            child = sized(range(3, 8)) { string(:alpha) }
            <<~XSD
              <xsd:complexType name="#{name}">
                <xsd:sequence>
                  <xsd:element name="#{child}" type="xsd:#{xsd_type}"/>
                </xsd:sequence>
              </xsd:complexType>
            XSD
          end
        }.join("\n      ")

        <<~XML
          <wsdl:definitions xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
                            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                            xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                            xmlns:tns="#{tns}" targetNamespace="#{tns}">
            <wsdl:types>
              <xsd:schema targetNamespace="#{tns}">
                #{type_defs}
              </xsd:schema>
            </wsdl:types>
          </wsdl:definitions>
        XML
      }.check(trial_count) do |xml|
        result = parse_wsdl(xml)
        expect(result).to eq(:parsed).or eq(:expected_error)
      end
    end
  end
end

# rubocop:enable Style/MultilineBlockChain
