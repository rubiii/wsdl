# frozen_string_literal: true

require 'spec_helper'

describe 'Integration with Oracle' do
  subject(:client) { WSDL.new fixture('wsdl/oracle') }

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

    expect(operation.body_parts).to eq([
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
end
