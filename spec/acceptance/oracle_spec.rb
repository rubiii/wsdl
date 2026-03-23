# frozen_string_literal: true

RSpec.describe 'Oracle' do
  subject(:client) { WSDL::Client.new fixture('wsdl/oracle') }

  it 'returns a map of services and ports' do
    expect(client.services).to include(
      'SAWSessionService' => {
        ports: {
          'SAWSessionServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=nQSessionService',
            operations: [
              { name: 'logon' },
              { name: 'logonex' },
              { name: 'logoff' },
              { name: 'keepAlive' },
              { name: 'getCurUser' },
              { name: 'getSessionEnvironment' },
              { name: 'getSessionVariables' },
              { name: 'impersonate' },
              { name: 'impersonateex' }
            ]
          }
        }
      },
      'WebCatalogService' => {
        ports: {
          'WebCatalogServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=webCatalogService',
            operations: [
              { name: 'deleteItem' },
              { name: 'createFolder' },
              { name: 'createLink' },
              { name: 'removeFolder' },
              { name: 'moveItem' },
              { name: 'copyItem' },
              { name: 'copyItem2' },
              { name: 'pasteItem2' },
              { name: 'getSubItems' },
              { name: 'getItemInfo' },
              { name: 'setItemProperty' },
              { name: 'maintenanceMode' },
              { name: 'readObjects' },
              { name: 'writeObjects' },
              { name: 'updateCatalogItemACL' },
              { name: 'setOwnership' },
              { name: 'setItemAttributes' }
            ]
          }
        }
      },
      'XmlViewService' => {
        ports: {
          'XmlViewServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=xmlViewService',
            operations: [
              { name: 'executeXMLQuery' },
              { name: 'upgradeXML' },
              { name: 'executeSQLQuery' },
              { name: 'fetchNext' },
              { name: 'cancelQuery' },
              { name: 'getPromptedFilters' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'SecurityService'
    port = 'SecurityServiceSoap'
    operation = client.operation(service, port, 'joinGroups')

    expect(operation.soap_action).to eq('#joinGroups')
    expect(operation.endpoint).to eq('https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=securityService')

    namespace = 'urn://oracle.bi.webservices/v7'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['joinGroups'],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[joinGroups group],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: false,
        min_occurs: '1',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[joinGroups group name],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups group accountType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:int',
        list: false
},
      { path: %w[joinGroups group guid],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups group displayName],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups member],
        kind: :complex,
        namespace: namespace,
        form: 'qualified',
        singular: false,
        min_occurs: '1',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[joinGroups member name],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups member accountType],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:int',
        list: false
},
      { path: %w[joinGroups member guid],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups member displayName],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[joinGroups sessionID],
        kind: :simple,
        namespace: namespace,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
}
    ])
  end

  describe 'xsd:any support' do
    let(:namespace) { 'urn://oracle.bi.webservices/v7' }
    let(:schemas) { WSDL::Parser::Result.parse(fixture('wsdl/oracle'), WSDL.http_adapter.new).schemas }

    it 'marks the JobInfo/detailedInfo element as allowing arbitrary content' do
      # The JobInfo type has a detailedInfo child with xs:any
      # <xsd:element maxOccurs="1" minOccurs="0" name="detailedInfo">
      #   <xsd:complexType>
      #     <xsd:sequence>
      #       <xsd:any maxOccurs="unbounded" minOccurs="0" processContents="skip"/>
      #     </xsd:sequence>
      #   </xsd:complexType>
      # </xsd:element>

      # Build from the response element which contains JobInfo with detailedInfo
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'sawsoap:getJobInfoResult', namespaces: { 'xmlns:sawsoap' => namespace } }
      elements = builder.build([part])

      body_parts = elements.first.to_a

      # Find the detailedInfo entry
      detailed_info_entry = body_parts.detect { |path, _data| path.last == 'detailedInfo' }
      expect(detailed_info_entry).not_to be_nil

      _path, data = detailed_info_entry
      expect(data[:any_content]).to be true
    end

    it 'generates an example message with placeholder for arbitrary content' do
      service = 'JobManagementService'
      port = 'JobManagementServiceSoap'
      operation = client.operation(service, port, 'getJobInfo')

      operation.contract.request.body.template(mode: :full).to_h

      # Navigate to the detailedInfo in the example
      # The structure is: getJobInfo -> jobID (string), returnOptions (optional), sessionID
      # But the response getJobInfoResult -> jobInfo -> ... -> detailedInfo
      # Let's check the response structure instead by building from the schema directly

      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'sawsoap:getJobInfoResult', namespaces: { 'xmlns:sawsoap' => namespace } }
      elements = builder.build([part])

      example = WSDL::Contract::PartContract.new(elements, section: :body).template(mode: :full).to_h

      # The detailedInfo element should have the any content placeholder
      detailed_info = example.dig(:getJobInfoResult, :jobInfo, :detailedInfo)
      expect(detailed_info).to include('(any)': 'arbitrary XML content allowed')
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
          tag('getJobInfoResult') do
            tag('jobInfo') do
              tag('jobStats') do
                tag('jobID', 12_345)
                tag('jobType', 'Report')
                tag('jobUser', 'admin')
                tag('jobState', 'Finished')
                tag('jobTotalMilliSec', '1500')
                tag('jobStartedTime', '2024-01-15T10:00:00Z')
                tag('jobIsCancelling', 'false')
              end
              tag('detailedInfo') do
                tag('ReportName', 'Sales Summary')
                tag('ExecutionTime', '1.5s')
                tag('RowCount', 150)
                tag('CustomMetadata') do
                  tag('Author', 'John Doe')
                  tag('Department', 'Finance')
                end
              end
            end
          end
        end
      end

      result = WSDL::Request::Serializer.new(document:, soap_version: '1.1', format_xml: false).serialize

      # Verify defined elements are serialized
      expect(result).to include('<jobID>12345</jobID>')
      expect(result).to include('<jobType>Report</jobType>')
      expect(result).to include('<jobState>Finished</jobState>')

      # Verify arbitrary content in detailedInfo is serialized
      expect(result).to include('<detailedInfo>')
      expect(result).to include('<ReportName>Sales Summary</ReportName>')
      expect(result).to include('<ExecutionTime>1.5s</ExecutionTime>')
      expect(result).to include('<RowCount>150</RowCount>')
      expect(result).to include('<CustomMetadata>')
      expect(result).to include('<Author>John Doe</Author>')
      expect(result).to include('<Department>Finance</Department>')
    end
  end
end
