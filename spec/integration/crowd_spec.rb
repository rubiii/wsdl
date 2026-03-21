# frozen_string_literal: true

RSpec.describe 'Integration with Atlassian Crowd' do
  subject(:client) { WSDL::Client.new fixture('wsdl/crowd') }

  it 'returns a map of services and ports' do
    expect(client.services).to eq(
      'SecurityServer' => {
        ports: {
          'SecurityServerHttpPort' => {
            type: 'http://schemas.xmlsoap.org/wsdl/soap/',
            location: 'http://magnesium:8095/crowd/services/SecurityServer'
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

    expect(request_body_paths(operation)).to eq([
      [['addAttributeToGroup'],
       { namespace: ns1, form: 'qualified', singular: true }
],
      [%w[addAttributeToGroup in0],
       { namespace: ns1, form: 'qualified', singular: true }
],
      [%w[addAttributeToGroup in0 name],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xsd:string' }
],
      [%w[addAttributeToGroup in0 token],
       { namespace: ns2, form: 'qualified', singular: true, type: 'xsd:string' }
],
      [%w[addAttributeToGroup in1],
       { namespace: ns1, form: 'qualified', singular: true, type: 'xsd:string' }
],
      [%w[addAttributeToGroup in2],
       { namespace: ns1, form: 'qualified', singular: true }
],
      [%w[addAttributeToGroup in2 name],
       { namespace: ns3, form: 'qualified', singular: true, type: 'xsd:string' }
],
      [%w[addAttributeToGroup in2 values],
       { namespace: ns3, form: 'qualified', singular: true }
],
      [%w[addAttributeToGroup in2 values string],
       { namespace: ns1, form: 'qualified', singular: false, type: 'xsd:string' }
]
    ])
  end

  context 'with a live mock service', :test_service do
    subject(:client) { WSDL::Client.new(service.wsdl_url) }

    let(:service) { WSDL::TestService[:crowd] }
    let(:service_name) { :SecurityServer }
    let(:port_name) { :SecurityServerHttpPort }

    before do
      service.start
    end

    it 'returns a group with nested arrays and mixed types' do
      operation = client.operation(service_name, port_name, :findGroupByName)

      operation.prepare do
        body do
          tag('findGroupByName') do
            tag('in0') do
              tag('name', 'app')
              tag('token', 'abc-123')
            end
            tag('in1', 'developers')
          end
        end
      end
      response = operation.invoke

      group = response.body[:findGroupByNameResponse][:out]
      expect(group[:ID]).to eq(1001)
      expect(group[:active]).to be true
      expect(group[:name]).to eq('developers')
      expect(group[:directoryId]).to eq(42)
      expect(group[:description]).to eq('Software developers')

      attrs = group[:attributes][:SOAPAttribute]
      expect(attrs).to be_an(Array)
      expect(attrs.size).to eq(2)
      expect(attrs[0][:name]).to eq('description')
      expect(attrs[0][:values][:string]).to eq(['Engineering team'])
      expect(attrs[1][:values][:string]).to eq(%w[internal ldap])

      expect(group[:members][:string]).to eq(%w[alice bob charlie])
    end

    it 'handles a minimal response without optional elements' do
      operation = client.operation(service_name, port_name, :findGroupByName)

      operation.prepare do
        body do
          tag('findGroupByName') do
            tag('in0') do
              tag('name', 'app')
              tag('token', 'abc-123')
            end
            tag('in1', 'nonexistent')
          end
        end
      end
      response = operation.invoke

      group = response.body[:findGroupByNameResponse][:out]
      expect(group[:ID]).to eq(0)
      expect(group[:active]).to be false
      expect(group[:attributes]).to be_nil
      expect(group[:members]).to be_nil
    end
  end
end
