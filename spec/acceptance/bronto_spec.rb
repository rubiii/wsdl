# frozen_string_literal: true

RSpec.describe 'Bronto' do
  subject(:client) { WSDL::Client.new fixture('wsdl/bronto') }

  let(:service_name) { :BrontoSoapApiImplService }
  let(:port_name)    { :BrontoSoapApiImplPort }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'BrontoSoapApiImplService' => {
        ports: {
          'BrontoSoapApiImplPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'https://api.bronto.com/v4',
            operations: [
              { name: 'readLogins' },
              { name: 'deleteLogins' },
              { name: 'addContactsToWorkflow' },
              { name: 'deleteDeliveryGroup' },
              { name: 'readApiTokens' },
              { name: 'updateMessageRules' },
              { name: 'deleteMessageRules' },
              { name: 'deleteMessages' },
              { name: 'readLists' },
              { name: 'addUpdateOrder' },
              { name: 'readMessageFolders' },
              { name: 'updateDeliveryGroup' },
              { name: 'readHeaderFooters' },
              { name: 'addFields' },
              { name: 'deleteApiTokens' },
              { name: 'addToList' },
              { name: 'deleteHeaderFooters' },
              { name: 'readActivities' },
              { name: 'deleteContacts' },
              { name: 'readConversions' },
              { name: 'updateMessages' },
              { name: 'addDeliveryGroup' },
              { name: 'readContacts' },
              { name: 'readWorkflows' },
              { name: 'updateApiTokens' },
              { name: 'readAccounts' },
              { name: 'updateDeliveries' },
              { name: 'addLists' },
              { name: 'readDeliveryRecipients' },
              { name: 'removeFromList' },
              { name: 'addContactEvent' },
              { name: 'addContacts' },
              { name: 'deleteDeliveries' },
              { name: 'readSegments' },
              { name: 'addDeliveries' },
              { name: 'login' },
              { name: 'addOrUpdateDeliveryGroup' },
              { name: 'deleteOrders' },
              { name: 'readDeliveries' },
              { name: 'addOrUpdateOrders' },
              { name: 'updateLists' },
              { name: 'updateMessageFolders' },
              { name: 'addOrUpdateContacts' },
              { name: 'addAccounts' },
              { name: 'deleteLists' },
              { name: 'addMessages' },
              { name: 'addHeaderFooters' },
              { name: 'readFields' },
              { name: 'deleteFromDeliveryGroup' },
              { name: 'updateFields' },
              { name: 'addMessageRules' },
              { name: 'clearLists' },
              { name: 'addMessageFolders' },
              { name: 'readMessageRules' },
              { name: 'deleteAccounts' },
              { name: 'readMessages' },
              { name: 'addConversion' },
              { name: 'updateAccounts' },
              { name: 'addLogins' },
              { name: 'deleteMessageFolders' },
              { name: 'updateHeaderFooters' },
              { name: 'updateContacts' },
              { name: 'readDeliveryGroups' },
              { name: 'addToDeliveryGroup' },
              { name: 'addSMSDeliveries' },
              { name: 'updateLogins' },
              { name: 'deleteFields' },
              { name: 'addApiTokens' }
            ]
          }
        }
      }
    )
  end

  it 'knows the operations' do
    operation = client.operation(service_name, port_name, :addLogins)

    expect(operation.soap_action).to eq('')
    expect(operation.endpoint).to eq('https://api.bronto.com/v4')

    namespace = 'http://api.bronto.com/v4'

    expect(operation.contract.request.body.paths).to eq([
      { path: ['addLogins'],
        kind: :complex,
        namespace:,
        form: 'qualified',
        singular: true,
        min_occurs: '1',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addLogins accounts],
        kind: :complex,
        namespace:,
        form: 'unqualified',
        singular: false,
        min_occurs: '0',
        max_occurs: 'unbounded',
        wildcard: false
},
      { path: %w[addLogins accounts username],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts password],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation],
        kind: :complex,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        wildcard: false
},
      { path: %w[addLogins accounts contactInformation organization],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation firstName],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation lastName],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation email],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation phone],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation address],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation address2],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation city],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation state],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation zip],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation country],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts contactInformation notes],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:string',
        list: false
},
      { path: %w[addLogins accounts permissionAgencyAdmin],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionAdmin],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionApi],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionUpgrade],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionFatigueOverride],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionMessageCompose],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionMessageApprove],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionMessageDelete],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionAutomatorCompose],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionListCreateSend],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionListCreate],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionSegmentCreate],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionFieldCreate],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionFieldReorder],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionSubscriberCreate],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
},
      { path: %w[addLogins accounts permissionSubscriberView],
        kind: :simple,
        namespace:,
        form: 'unqualified',
        singular: true,
        min_occurs: '0',
        max_occurs: '1',
        type: 'xs:boolean',
        list: false
}
    ])
  end

  # explicit headers. reference: http://www.ibm.com/developerworks/library/ws-tip-headers/index.html
  it 'creates an example header' do
    operation = client.operation(service_name, port_name, :addLogins)

    expect(operation.contract.request.header.template(mode: :full).to_h).to eq(
      sessionHeader: {
        sessionId: 'string'
      }
    )
  end

  it 'creates an example body' do
    operation = client.operation(service_name, port_name, :addLogins)

    expect(operation.contract.request.body.template(mode: :full).to_h).to eq(
      addLogins: {
        accounts: [
          {
            username: 'string',
            password: 'string',
            contactInformation: {
              organization: 'string',
              firstName: 'string',
              lastName: 'string',
              email: 'string',
              phone: 'string',
              address: 'string',
              address2: 'string',
              city: 'string',
              state: 'string',
              zip: 'string',
              country: 'string',
              notes: 'string'
            },
            permissionAgencyAdmin: 'boolean',
            permissionAdmin: 'boolean',
            permissionApi: 'boolean',
            permissionUpgrade: 'boolean',
            permissionFatigueOverride: 'boolean',
            permissionMessageCompose: 'boolean',
            permissionMessageApprove: 'boolean',
            permissionMessageDelete: 'boolean',
            permissionAutomatorCompose: 'boolean',
            permissionListCreateSend: 'boolean',
            permissionListCreate: 'boolean',
            permissionSegmentCreate: 'boolean',
            permissionFieldCreate: 'boolean',
            permissionFieldReorder: 'boolean',
            permissionSubscriberCreate: 'boolean',
            permissionSubscriberView: 'boolean'
          }
        ]
      }
    )
  end

  it 'creates a request with a header' do
    operation = client.operation(service_name, port_name, :addLogins)

    operation.prepare do
      header do
        tag('sessionHeader') do
          tag('sessionId', '23')
        end
      end
      body do
        tag('addLogins') do
          tag('accounts') do
            tag('username', 'admin')
            tag('password', 'secert')
            tag('contactInformation') do
              tag('firstName', 'brew')
              tag('email', 'brew@example.com')
            end
            tag('permissionApi', true)
          end
        end
      end
    end

    expected = Nokogiri.XML('
      <env:Envelope
          xmlns:ns0="http://api.bronto.com/v4"
          xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
        <env:Header>
          <ns0:sessionHeader>
            <sessionId>23</sessionId>
          </ns0:sessionHeader>
        </env:Header>
        <env:Body>
          <ns0:addLogins>
            <accounts>
              <username>admin</username>
              <password>secert</password>
              <contactInformation>
                <firstName>brew</firstName>
                <email>brew@example.com</email>
              </contactInformation>
              <permissionApi>true</permissionApi>
            </accounts>
          </ns0:addLogins>
        </env:Body>
      </env:Envelope>
    ')

    expect(Nokogiri.XML(operation.to_xml))
      .to be_equivalent_to(expected).respecting_element_order
  end
end
