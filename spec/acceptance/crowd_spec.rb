# frozen_string_literal: true

RSpec.describe 'Atlassian Crowd' do
  subject(:client) { WSDL::Client.new WSDL.parse(fixture('wsdl/crowd')) }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'SecurityServer' => {
        ports: {
          'SecurityServerHttpPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://magnesium:8095/crowd/services/SecurityServer',
            operations: [
              { name: 'findAllGroupRelationships' },
              { name: 'addGroup' },
              { name: 'addPrincipalToRole' },
              { name: 'findPrincipalByToken' },
              { name: 'updatePrincipalCredential' },
              { name: 'getGrantedAuthorities' },
              { name: 'addPrincipal' },
              { name: 'addAttributeToPrincipal' },
              { name: 'invalidatePrincipalToken' },
              { name: 'findAllGroupNames' },
              { name: 'findRoleMemberships' },
              { name: 'removePrincipal' },
              { name: 'isValidPrincipalToken' },
              { name: 'authenticatePrincipalSimple' },
              { name: 'removeRole' },
              { name: 'getCookieInfo' },
              { name: 'updatePrincipalAttribute' },
              { name: 'searchGroups' },
              { name: 'getCacheTime' },
              { name: 'isRoleMember' },
              { name: 'updateGroup' },
              { name: 'addAttributeToGroup' },
              { name: 'findAllRoleNames' },
              { name: 'findRoleByName' },
              { name: 'isCacheEnabled' },
              { name: 'findGroupByName' },
              { name: 'findGroupWithAttributesByName' },
              { name: 'removePrincipalFromRole' },
              { name: 'findPrincipalWithAttributesByName' },
              { name: 'authenticatePrincipal' },
              { name: 'findGroupMemberships' },
              { name: 'addPrincipalToGroup' },
              { name: 'removeGroup' },
              { name: 'removeAttributeFromGroup' },
              { name: 'removeAttributeFromPrincipal' },
              { name: 'addRole' },
              { name: 'findAllPrincipalNames' },
              { name: 'createPrincipalToken' },
              { name: 'searchRoles' },
              { name: 'removePrincipalFromGroup' },
              { name: 'findPrincipalByName' },
              { name: 'resetPrincipalCredential' },
              { name: 'updateGroupAttribute' },
              { name: 'isGroupMember' },
              { name: 'searchPrincipals' },
              { name: 'getDomain' },
              { name: 'authenticateApplication' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    service = 'SecurityServer'
    port = 'SecurityServerHttpPort'
    operation = client.operation(service, port, 'addAttributeToGroup')

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('http://magnesium:8095/crowd/services/SecurityServer')

    ns1 = 'urn:SecurityServer'
    ns2 = 'http://authentication.integration.crowd.atlassian.com'
    ns3 = 'http://soap.integration.crowd.atlassian.com'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['addAttributeToGroup'],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addAttributeToGroup in0],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addAttributeToGroup in0 name],
        kind: :simple,
        namespace: ns2,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[addAttributeToGroup in0 token],
        kind: :simple,
        namespace: ns2,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[addAttributeToGroup in1],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[addAttributeToGroup in2],
        kind: :complex,
        namespace: ns1,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addAttributeToGroup in2 name],
        kind: :simple,
        namespace: ns3,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xsd:string',
        list: false
},
      { path: %w[addAttributeToGroup in2 values],
        kind: :complex,
        namespace: ns3,
        form: 'qualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addAttributeToGroup in2 values string],
        kind: :simple,
        namespace: ns1,
        form: 'qualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        type: 'xsd:string',
        list: false
}
    ])
  end
end
