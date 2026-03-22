# frozen_string_literal: true

RSpec.describe WSDL::Response::Builder do
  def schema_elements(fixture, operation_name:, service: nil, port: nil)
    client = WSDL::Client.new(fixture(fixture))

    if service
      client.operation(service, port, operation_name)
    else
      client.operation(operation_name)
    end.contract.response.body.elements
  end

  describe '#to_xml' do
    context 'with a simple service (BLZService)' do
      subject(:builder) do
        described_class.new(
          schema_elements: schema_elements('wsdl/blz_service',
                                           service: :BLZService, port: :BLZServiceSOAP11port_http,
                                           operation_name: :getBank)
        )
      end

      it 'serializes a response hash to SOAP XML' do
        xml = builder.to_xml(
          details: {
            bezeichnung: 'Deutsche Bank',
            bic: 'DEUTDEMM',
            ort: 'München',
            plz: '80271'
          }
        )

        doc = Nokogiri::XML(xml)
        ns = { 'env' => WSDL::NS::SOAP_1_1, 'ns' => 'http://thomas-bayer.com/blz/' }

        expect(doc.at_xpath('//env:Body/ns:getBankResponse/ns:details/ns:bezeichnung', ns).text)
          .to eq('Deutsche Bank')
        expect(doc.at_xpath('//env:Body/ns:getBankResponse/ns:details/ns:bic', ns).text)
          .to eq('DEUTDEMM')
      end

      it 'omits optional elements not present in the hash' do
        xml = builder.to_xml(details: { bezeichnung: 'Test' })

        doc = Nokogiri::XML(xml)
        ns = { 'env' => WSDL::NS::SOAP_1_1, 'ns' => 'http://thomas-bayer.com/blz/' }

        expect(doc.at_xpath('//ns:bezeichnung', ns).text).to eq('Test')
        expect(doc.at_xpath('//ns:bic', ns)).to be_nil
      end

      it 'handles boolean false values' do
        # BLZ doesn't have booleans, but we can verify false isn't swallowed
        # by checking a string field with a falsy-looking value
        xml = builder.to_xml(details: { bezeichnung: '' })

        doc = Nokogiri::XML(xml)
        ns = { 'ns' => 'http://thomas-bayer.com/blz/' }

        expect(doc.at_xpath('//ns:bezeichnung', ns).text).to eq('')
      end
    end

    context 'with arrays and mixed types (Betfair)' do
      subject(:builder) do
        described_class.new(
          schema_elements: schema_elements('wsdl/betfair', operation_name: :getMUBetsLite)
        )
      end

      it 'serializes array elements' do
        xml = builder.to_xml(
          Result: {
            header: { errorCode: 'OK', minorErrorCode: '', sessionToken: 'tok', timestamp: '2025-01-01T00:00:00Z' },
            betLites: {
              MUBetLite: [
                { betId: 1, transactionId: 2, marketId: 3, size: 10.0,
                  betStatus: 'MU', betCategoryType: 'E', betPersistenceType: 'NONE', bspLiability: 0.0
},
                { betId: 4, transactionId: 5, marketId: 3, size: 20.0,
                  betStatus: 'MU', betCategoryType: 'E', betPersistenceType: 'IP', bspLiability: 1.5
}
              ]
            },
            errorCode: 'OK', minorErrorCode: '', totalRecordCount: 2
          }
        )

        doc = Nokogiri::XML(xml)
        ns_types = 'http://www.betfair.com/publicapi/types/exchange/v5/'
        bets = doc.xpath('//ns:MUBetLite', 'ns' => ns_types)

        expect(bets.size).to eq(2)
        expect(bets[0].at_xpath('betId').text).to eq('1')
        expect(bets[1].at_xpath('size').text).to eq('20.0')
      end

      it 'serializes Time objects as xmlschema (ISO 8601)' do
        xml = builder.to_xml(
          Result: {
            header: {
              errorCode: 'OK', minorErrorCode: '', sessionToken: 'tok',
              timestamp: Time.utc(2025, 6, 15, 14, 30, 0)
            },
            betLites: {},
            errorCode: 'OK', minorErrorCode: '', totalRecordCount: 0
          }
        )

        doc = Nokogiri::XML(xml)

        # timestamp is unqualified so use local-name() XPath
        expect(doc.at_xpath('//*[local-name()="timestamp"]').text)
          .to eq('2025-06-15T14:30:00Z')
      end

      it 'handles qualified and unqualified elements' do
        xml = builder.to_xml(
          Result: {
            header: { errorCode: 'OK', minorErrorCode: '', sessionToken: 'tok', timestamp: '2025-01-01T00:00:00Z' },
            betLites: {},
            errorCode: 'OK', minorErrorCode: '', totalRecordCount: 0
          }
        )

        doc = Nokogiri::XML(xml)
        ns_betfair = 'http://www.betfair.com/publicapi/v5/BFExchangeService/'

        # Wrapper is qualified
        wrapper = doc.at_xpath('//env:Body/*', 'env' => WSDL::NS::SOAP_1_1)
        expect(wrapper.namespace.href).to eq(ns_betfair)

        # Inner elements like errorCode are unqualified (no namespace)
        result = wrapper.at_xpath('*[local-name()="Result"]')
        error_code = result.at_xpath('*[local-name()="errorCode"]')
        expect(error_code).not_to be_nil
        expect(error_code.namespace).to be_nil
      end
    end

    context 'with booleans and nested errors (Interhome)' do
      subject(:builder) do
        described_class.new(
          schema_elements: schema_elements('wsdl/interhome',
                                           service: :WebService, port: :WebServiceSoap,
                                           operation_name: :ClientBooking)
        )
      end

      it 'serializes boolean values' do
        xml = builder.to_xml(ClientBookingResult: { Ok: true, BookingID: 'BK-123' })

        doc = Nokogiri::XML(xml)
        ns = { 'ns' => 'http://www.interhome.com/webservice' }

        expect(doc.at_xpath('//ns:Ok', ns).text).to eq('true')
      end

      it 'serializes false boolean values' do
        xml = builder.to_xml(
          ClientBookingResult: {
            Ok: false,
            Errors: {
              Error: [{ Number: 1001, Description: 'Bad input' }]
            }
          }
        )

        doc = Nokogiri::XML(xml)
        ns = { 'ns' => 'http://www.interhome.com/webservice' }

        expect(doc.at_xpath('//ns:Ok', ns).text).to eq('false')
        expect(doc.at_xpath('//ns:Number', ns).text).to eq('1001')
      end
    end

    it 'produces SOAP 1.2 envelopes when specified' do
      elements = schema_elements('wsdl/blz_service',
                                 service: :BLZService, port: :BLZServiceSOAP12port_http,
                                 operation_name: :getBank)

      builder = described_class.new(schema_elements: elements, soap_version: '1.2')
      xml = builder.to_xml(details: { bezeichnung: 'Test' })

      doc = Nokogiri::XML(xml)
      expect(doc.root.namespace.href).to eq(WSDL::NS::SOAP_1_2)
    end

    context 'with RPC/literal style' do
      let(:service) { :SampleService }
      let(:port) { :Sample }

      it 'wraps message parts in an operationNameResponse element' do
        elements = schema_elements('wsdl/rpc_literal', service:, port:, operation_name: :op1)
        builder = described_class.new(
          schema_elements: elements, output_style: 'rpc/literal',
          operation_name: 'op1', output_namespace: 'http://apiNamespace.com'
        )

        xml = builder.to_xml(data1: 10, data2: 20)
        doc = Nokogiri::XML(xml)

        wrapper = doc.at_xpath('//env:Body/*', 'env' => WSDL::NS::SOAP_1_1)
        expect(wrapper.name).to eq('op1Response')
        expect(wrapper.namespace.href).to eq('http://apiNamespace.com')

        expect(wrapper.at_xpath('*[local-name()="op1Return"]/*[local-name()="data1"]').text).to eq('10')
        expect(wrapper.at_xpath('*[local-name()="op1Return"]/*[local-name()="data2"]').text).to eq('20')
      end

      it 'handles RPC wrapper with a different namespace' do
        elements = schema_elements('wsdl/rpc_literal', service:, port:, operation_name: :op2)
        builder = described_class.new(
          schema_elements: elements, output_style: 'rpc/literal',
          operation_name: 'op2', output_namespace: 'http://op2Namespace.com'
        )

        xml = builder.to_xml(data1: 1, data2: 2)
        doc = Nokogiri::XML(xml)

        wrapper = doc.at_xpath('//env:Body/*', 'env' => WSDL::NS::SOAP_1_1)
        expect(wrapper.name).to eq('op2Response')
        expect(wrapper.namespace.href).to eq('http://op2Namespace.com')
      end

      it 'handles RPC wrapper without a namespace' do
        elements = schema_elements('wsdl/rpc_literal', service:, port:, operation_name: :op3)
        builder = described_class.new(
          schema_elements: elements, output_style: 'rpc/literal',
          operation_name: 'op3', output_namespace: nil
        )

        xml = builder.to_xml(RefDataElem: 42)
        doc = Nokogiri::XML(xml)

        wrapper = doc.at_xpath('//env:Body/*', 'env' => WSDL::NS::SOAP_1_1)
        expect(wrapper.name).to eq('op3Response')
        expect(wrapper.namespace).to be_nil
      end
    end
  end

  describe '#validate!' do
    subject(:builder) do
      described_class.new(
        schema_elements: schema_elements('wsdl/blz_service',
                                         service: :BLZService, port: :BLZServiceSOAP11port_http,
                                         operation_name: :getBank)
      )
    end

    it 'passes for a valid hash' do
      expect { builder.validate!(details: { bezeichnung: 'Test' }) }.not_to raise_error
    end

    it 'rejects unknown elements' do
      expect { builder.validate!(detials: { bezeichnung: 'Test' }) }
        .to raise_error(WSDL::ResponseBuildError, /Unknown element :detials/)
    end

    it 'rejects unknown nested elements' do
      expect { builder.validate!(details: { unknown_field: 'Test' }) }
        .to raise_error(WSDL::ResponseBuildError, /Unknown element :unknown_field/)
    end

    it 'rejects missing required elements' do
      elements = schema_elements('wsdl/interhome',
                                 service: :WebService, port: :WebServiceSoap,
                                 operation_name: :ClientBooking)
      interhome_builder = described_class.new(schema_elements: elements)

      expect { interhome_builder.validate!(ClientBookingResult: {}) }
        .to raise_error(WSDL::ResponseBuildError, /Missing required element "Ok"/)
    end

    it 'rejects type mismatches' do
      expect { builder.validate!(details: { bezeichnung: 123 }) }
        .to raise_error(WSDL::ResponseBuildError, /Type mismatch.*expected.*string.*got Integer/)
    end

    it 'rejects arrays for singular elements' do
      expect { builder.validate!(details: [{ bezeichnung: 'Test' }]) }
        .to raise_error(WSDL::ResponseBuildError, /Singular element.*received an Array/)
    end

    it 'accepts arrays for plural elements' do
      elements = schema_elements('wsdl/interhome',
                                 service: :WebService, port: :WebServiceSoap,
                                 operation_name: :ClientBooking)
      interhome_builder = described_class.new(schema_elements: elements)

      expect {
        interhome_builder.validate!(
          ClientBookingResult: {
            Ok: true,
            Errors: {
              Error: [
                { Number: 1, Description: 'first' },
                { Number: 2, Description: 'second' }
              ]
            }
          }
        )
      }.not_to raise_error
    end
  end
end
