# frozen_string_literal: true

RSpec.describe 'Equifax' do
  subject(:client) { WSDL::Client.new(service.wsdl_url, strict_schema: false) }

  let(:service) { WSDL::TestService[:equifax] }
  let(:service_name) { :canadav2 }
  let(:port_name)    { :canadaHttpPortV2 }

  before do
    service.start
  end

  it 'returns a response with attributes on elements' do
    operation = client.operation(service_name, port_name, :startTransaction)

    operation.prepare do
      body do
        tag('InitialRequest') do
          tag('Identity') do
            tag('Name') do
              tag('FirstName', 'John')
              tag('LastName', 'Smith')
            end
          end
        end
      end
    end
    response = operation.invoke
    body = response.body[:InitialResponse]

    # Attributes are accessible via _-prefixed keys with type coercion
    expect(body[:_transactionKey]).to eq('TXN-98765')

    verification = body[:ApplicationVerification]
    expect(verification[:_retryPossible]).to be false

    address = verification[:OutputAddress].first
    expect(address[:_isStandardized]).to be true
    expect(address[:_addressType]).to eq('current')
    expect(address[:HybridAddress][:City]).to eq('Toronto')

    assessment = body[:AssesmentComplete]
    expect(assessment[:_name]).to eq('IDVerification')
    expect(assessment[:Score]).to eq(92)

    query = body[:InteractiveQuery]
    expect(query[:_interactiveQueryId]).to eq(1)
    expect(query[:Question].first[:QuestionText]).to eq('Which street have you lived on?')
  end
end
