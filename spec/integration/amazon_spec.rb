# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Amazon' do
  subject(:client) { WSDL::Client.new fixture('wsdl/amazon') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AmazonFPS' => {
        ports: {
          'AmazonFPSPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fps.amazonaws.com'
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'AmazonFPS'
    port = 'AmazonFPSPort'
    operation = client.operation(service, port, 'Pay')

    expect(operation.soap_action).to eq('Pay')
    expect(operation.endpoint).to eq('https://fps.amazonaws.com')

    namespace = 'http://fps.amazonaws.com/doc/2008-09-17/'

    expect(request_body_paths(operation)).to eq([
      [['Pay'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay SenderTokenId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay RecipientTokenId],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionAmount],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay TransactionAmount CurrencyCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionAmount Value],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay ChargeFeeTo],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay CallerReference],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay CallerDescription],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay SenderDescription],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay DescriptorPolicy],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay DescriptorPolicy SoftDescriptorType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay DescriptorPolicy CSOwner],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay TransactionTimeoutInMins],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:integer'
 }
],
      [%w[Pay MarketplaceFixedFee],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[Pay MarketplaceFixedFee CurrencyCode],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay MarketplaceFixedFee Value],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:string'
 }
],
      [%w[Pay MarketplaceVariableFee],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xs:decimal'
 }
]
    ])
  end

  describe 'xsd:any support' do
    let(:namespace) { 'http://fps.amazonaws.com/doc/2008-09-17/' }
    let(:schemas) { WSDL::Parser::Result.new(fixture('wsdl/amazon'), WSDL.http_adapter.new).schemas }

    it 'marks the Error/Detail element as allowing arbitrary content' do
      # The Error element has a Detail child with xs:any
      # <xs:element name="Detail" minOccurs="0">
      #   <xs:complexType>
      #     <xs:sequence>
      #       <xs:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
      #     </xs:sequence>
      #   </xs:complexType>
      # </xs:element>

      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => namespace } }
      elements = builder.build([part])

      error_element = elements.first
      expect(error_element.name).to eq('Error')

      detail_element = error_element.children.detect { |c| c.name == 'Detail' }
      expect(detail_element).not_to be_nil
      expect(detail_element.any_content?).to be true
    end

    it 'includes any_content flag in body_parts for elements with xs:any' do
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => namespace } }
      elements = builder.build([part])

      body_parts = elements.first.to_a

      # Find the Detail entry
      detail_entry = body_parts.detect { |path, _data| path == %w[Error Detail] }
      expect(detail_entry).not_to be_nil

      _path, data = detail_entry
      expect(data[:any_content]).to be true
    end

    it 'generates an example message with placeholder for arbitrary content' do
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => namespace } }
      elements = builder.build([part])

      example = WSDL::Contract::PartContract.new(elements, section: :body).template(mode: :full).to_h

      # The Detail element should have the any content placeholder
      detail = example.dig(:Error, :Detail)
      expect(detail).to include('(any)': 'arbitrary XML content allowed')
    end

    it 'serializes arbitrary content in elements with xs:any' do
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'tns:Error', namespaces: { 'xmlns:tns' => namespace } }
      elements = builder.build([part])

      document = WSDL::Request::Document.new
      context = WSDL::Request::DSLContext.new(
        document:,
        security: WSDL::Security::Config.new,
        request_limits: WSDL.limits.to_h
      )

      SpecSupport::RequestDSLHelper.emit_hash_section(context, :body, {
        Error: {
          Type: 'Sender',
          Code: 'InvalidParameterValue',
          Message: 'Value for parameter is invalid.',
          Detail: {
            # Arbitrary content via xs:any
            Parameter: 'Amount',
            ExpectedType: 'Decimal',
            ReceivedValue: 'not-a-number'
          }
        }
      }, elements)

      result = WSDL::Request::Serializer.new(document:, soap_version: '1.1', pretty_print: false).serialize

      # Verify defined elements are serialized
      expect(result).to include('<Type>Sender</Type>')
      expect(result).to include('<Code>InvalidParameterValue</Code>')
      expect(result).to include('<Message>Value for parameter is invalid.</Message>')

      # Verify arbitrary content is serialized
      expect(result).to include('<Detail>')
      expect(result).to include('<Parameter>Amount</Parameter>')
      expect(result).to include('<ExpectedType>Decimal</ExpectedType>')
      expect(result).to include('<ReceivedValue>not-a-number</ReceivedValue>')
    end
  end
end
