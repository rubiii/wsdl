# frozen_string_literal: true

WSDL::TestService.define(:equifax, wsdl: 'wsdl/equifax') do
  operation :startTransaction do
    on LastName: 'Smith', FirstName: 'John' do
      {
        _transactionKey: 'TXN-98765',
        FieldChecksFailed: {
          FieldInErrorXPath: []
        },
        ApplicationVerification: {
          _retryPossible: false,
          OutputAddress: [
            {
              _isStandardized: true,
              _addressType: 'current',
              FreeFormAddress: { AddressLine: ['123 Main St, Toronto ON M5V 2H1'] },
              HybridAddress: {
                AddressLine: ['123 Main St'],
                City: 'Toronto',
                Province: 'ON',
                PostalCode: 'M5V 2H1'
              }
            }
          ],
          ReasonCode: [
            { _description: 'Identity verified' }
          ]
        },
        FraudCheckFailed: {
          OutputAddress: [
            {
              _isStandardized: true,
              _addressType: 'current',
              FreeFormAddress: { AddressLine: ['123 Main St, Toronto ON M5V 2H1'] },
              HybridAddress: {
                AddressLine: ['123 Main St'],
                City: 'Toronto',
                Province: 'ON',
                PostalCode: 'M5V 2H1'
              }
            }
          ],
          ReasonCode: [
            { _description: 'No fraud indicators' }
          ]
        },
        InteractiveQuery: {
          _answerId: 0,
          _questionId: 0,
          _interactiveQueryId: 1,
          Question: [
            {
              _answerId: 1,
              _questionId: 101,
              QuestionText: 'Which street have you lived on?',
              AnswerChoice: [
                { _answerId: 1 },
                { _answerId: 2 },
                { _answerId: 3 }
              ]
            }
          ]
        },
        AssesmentComplete: {
          _name: 'IDVerification',
          OutputAddress: [
            {
              _isStandardized: true,
              _addressType: 'current',
              FreeFormAddress: { AddressLine: ['123 Main St, Toronto ON M5V 2H1'] },
              HybridAddress: {
                AddressLine: ['123 Main St'],
                City: 'Toronto',
                Province: 'ON',
                PostalCode: 'M5V 2H1'
              }
            }
          ],
          ReasonCode: [{ _description: 'Passed' }],
          Score: 92,
          RiskStrategyDecision: 'Accept',
          AtomicScores: {
            SimpleInteractiveQueryScore: 100
          }
        },
        SystemProblem: ''
      }
    end
  end
end

RSpec.describe 'Equifax' do
  subject(:client) { WSDL::Client.new(WSDL.parse(service.wsdl_url)) }

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
              tag('MiddleName', '')
              tag('MiddleInitial', '')
              tag('LastName', 'Smith')
            end
            tag('Address', addressType: 'Current') do
              tag('FreeFormAddress') do
                tag('AddressLine', '123 Main St, Toronto ON M5V 2H1')
              end
              tag('HybridAddress') do
                tag('AddressLine', '123 Main St')
                tag('City', 'Toronto')
                tag('Province', 'ON')
                tag('PostalCode', 'M5V 2H1')
              end
            end
          end
          tag('ProcessingOptions') do
            tag('Language', 'en')
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
