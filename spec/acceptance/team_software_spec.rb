# frozen_string_literal: true

RSpec.describe 'TeamSoftware' do
  subject(:client) { RoundtripCandidates.mock_client_from_manifest(fixture('wsdl/team_software/manifest'), http_mock) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'ServiceManager' => {
        ports: {
          'BasicHttpBinding_IWinTeamServiceManager' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://winteamservicestest.myteamsoftware.com/Services.svc',
            operations: [
              { name: 'Login' },
              { name: 'SaveEmployee' },
              { name: 'SavePartialEmployee' },
              { name: 'GetEmployeeComboListXML' },
              { name: 'eHubValidEmployee' },
              { name: 'eHubValidCustomer' },
              { name: 'ValidEmployee' },
              { name: 'EmployeeProfile' },
              { name: 'EmployeeComplianceCodeImport' },
              { name: 'EmployeeComplianceCodesCompletedExport' },
              { name: 'EmployeeComplianceCodesNotCompletedExport' },
              { name: 'PS_TT_TK_Hours_Import' },
              { name: 'PS_TT_TK_Hours_BatchImport' },
              { name: 'CyCop_JobExport' },
              { name: 'CyCop_EmployeeExport' },
              { name: 'CyCop_SingleEmployeeExport' },
              { name: 'CyCop_PostExport' },
              { name: 'CyCop_JobContactExport' },
              { name: 'CyCop_SchedulingExport' },
              { name: 'CyCop_JobHolidayExport' },
              { name: 'GetActiveDirectoryEmployees' },
              { name: 'UploadNewHireDocuments' },
              { name: 'LMS_GetActiveEmployees' },
              { name: 'LMS_ProcessFile' },
              { name: 'UpdateComplianceCode' },
              { name: 'DeleteComplianceCode' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'ServiceManager'
    port = 'BasicHttpBinding_IWinTeamServiceManager'
    operation = client.operation(service, port, 'Login')

    expect(operation.soap_action).to eq('http://tempuri.org/IWinTeamServiceManager/Login')
    expect(operation.endpoint).to eq('https://winteamservicestest.myteamsoftware.com/Services.svc')

    namespace = 'http://tempuri.org/'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['Login'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false },
      { path: %w[Login MappingKey],
        kind: :simple,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false }
    ])
  end
end
