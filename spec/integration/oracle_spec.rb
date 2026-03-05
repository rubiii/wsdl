# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Oracle' do
  subject(:client) { WSDL::Client.new fixture('wsdl/oracle') }

  it 'returns a map of services and ports' do
    expect(client.services).to include(
      'SAWSessionService' => {
        ports: {
          'SAWSessionServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=nQSessionService'
          }
        }
      },
      'WebCatalogService' => {
        ports: {
          'WebCatalogServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=webCatalogService'
          }
        }
      },
      'XmlViewService' => {
        ports: {
          'XmlViewServiceSoap' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://fap0023-bi.oracleads.com/analytics-ws/saw.dll?SoapImpl=xmlViewService'
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

    expect(request_body_paths(operation)).to eq([
      [['joinGroups'],
       { namespace: namespace, form: 'qualified', singular: true }
],
      [%w[joinGroups group],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[joinGroups group name],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups group accountType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:int'
}
],
      [%w[joinGroups group guid],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups group displayName],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups member],
       { namespace: namespace, form: 'qualified', singular: false }
],
      [%w[joinGroups member name],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups member accountType],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:int'
}
],
      [%w[joinGroups member guid],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups member displayName],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
],
      [%w[joinGroups sessionID],
       { namespace: namespace, form: 'qualified', singular: true,
         type: 'xsd:string'
}
]
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

      request_template(operation, section: :body)

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
      builder = WSDL::XML::ElementBuilder.new(schemas)

      part = { element: 'sawsoap:getJobInfoResult', namespaces: { 'xmlns:sawsoap' => namespace } }
      elements = builder.build([part])

      document = WSDL::Request::AST.new
      context = WSDL::Request::DSLContext.new(
        document:,
        security: WSDL::Security::Config.new,
        request_limits: WSDL.limits.to_h
      )

      SpecSupport::RequestDSLHelper.emit_hash_section(context, :body, {
        getJobInfoResult: {
          jobInfo: {
            jobStats: {
              jobID: 12_345,
              jobType: 'Report',
              jobUser: 'admin',
              jobState: 'Finished',
              jobTotalMilliSec: '1500',
              jobStartedTime: '2024-01-15T10:00:00Z',
              jobIsCancelling: 'false'
            },
            detailedInfo: {
              # Arbitrary content via xs:any
              ReportName: 'Sales Summary',
              ExecutionTime: '1.5s',
              RowCount: 150,
              CustomMetadata: {
                Author: 'John Doe',
                Department: 'Finance'
              }
            }
          }
        }
      }, elements)

      result = WSDL::Request::Serializer.new(document:, soap_version: '1.1', pretty_print: false).serialize

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
