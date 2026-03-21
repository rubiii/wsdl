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
