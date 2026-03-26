# frozen_string_literal: true

RSpec.describe 'Amazon' do
  subject(:client) { WSDL::Client.new fixture('wsdl/amazon') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'AmazonFPS' => {
        ports: {
          'AmazonFPSPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fps.amazonaws.com',
            operations: [
              { name: 'CancelToken' },
              { name: 'Cancel' },
              { name: 'FundPrepaid' },
              { name: 'GetAccountActivity' },
              { name: 'GetAccountBalance' },
              { name: 'GetDebtBalance' },
              { name: 'GetOutstandingDebtBalance' },
              { name: 'GetPrepaidBalance' },
              { name: 'GetTokenByCaller' },
              { name: 'CancelSubscriptionAndRefund' },
              { name: 'GetTokenUsage' },
              { name: 'GetTokens' },
              { name: 'GetTotalPrepaidLiability' },
              { name: 'GetTransaction' },
              { name: 'GetTransactionStatus' },
              { name: 'GetPaymentInstruction' },
              { name: 'InstallPaymentInstruction' },
              { name: 'Pay' },
              { name: 'Refund' },
              { name: 'Reserve' },
              { name: 'Settle' },
              { name: 'SettleDebt' },
              { name: 'WriteOffDebt' },
              { name: 'GetRecipientVerificationStatus' },
              { name: 'VerifySignature' }
            ]
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

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Pay'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Pay SenderTokenId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay RecipientTokenId],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay TransactionAmount],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Pay TransactionAmount CurrencyCode],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay TransactionAmount Value],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay ChargeFeeTo],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay CallerReference],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay CallerDescription],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay SenderDescription],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay DescriptorPolicy],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Pay DescriptorPolicy SoftDescriptorType],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay DescriptorPolicy CSOwner],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay TransactionTimeoutInMins],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:integer',
        list: false
},
      { path: %w[Pay MarketplaceFixedFee],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[Pay MarketplaceFixedFee CurrencyCode],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay MarketplaceFixedFee Value],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[Pay MarketplaceVariableFee],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:decimal',
        list: false
}
    ])
  end

  describe 'xsd:any support' do
    let(:namespace) { 'http://fps.amazonaws.com/doc/2008-09-17/' }
    let(:schemas) { parse_schemas(fixture('wsdl/amazon')) }

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
      document = WSDL::Request::Envelope.new
      context = WSDL::Request::DSLContext.new(
        document:,
        security: WSDL::Security::Config.new,
        limits: WSDL.limits
      )

      context.instance_exec do
        body do
          tag('Error') do
            tag('Type', 'Sender')
            tag('Code', 'InvalidParameterValue')
            tag('Message', 'Value for parameter is invalid.')
            tag('Detail') do
              tag('Parameter', 'Amount')
              tag('ExpectedType', 'Decimal')
              tag('ReceivedValue', 'not-a-number')
            end
          end
        end
      end

      result = WSDL::Request::Serializer.new(document:, soap_version: '1.1').serialize

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

  def parse_schemas(wsdl_path)
    documents = WSDL::Parser::DocumentCollection.new
    schemas = WSDL::Schema::Collection.new
    source = WSDL::Resolver::Source.validate_wsdl!(wsdl_path)
    sandbox = [File.dirname(File.expand_path(wsdl_path))]
    loader = WSDL::Resolver::Loader.new(WSDL.http_client.new, sandbox_paths: sandbox)
    importer = WSDL::Resolver::Importer.new(loader, documents, schemas, WSDL::ParseOptions.default)
    importer.import(source.value)
    schemas
  end
end
