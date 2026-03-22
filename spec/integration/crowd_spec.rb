# frozen_string_literal: true

WSDL::TestService.define(:crowd, wsdl: 'wsdl/crowd') do
  operation :findGroupByName do
    on in1: 'developers' do
      {
        out: {
          ID: 1001,
          active: true,
          attributes: {
            SOAPAttribute: [
              { name: 'description', values: { string: ['Engineering team'] } },
              { name: 'type', values: { string: %w[internal ldap] } }
            ]
          },
          conception: '2020-03-15T10:00:00Z',
          description: 'Software developers',
          directoryId: 42,
          lastModified: '2025-01-10T14:30:00Z',
          members: { string: %w[alice bob charlie] },
          name: 'developers'
        }
      }
    end

    on in1: 'nonexistent' do
      {
        out: {
          ID: 0,
          active: false,
          conception: '1970-01-01T00:00:00Z',
          description: '',
          directoryId: 0,
          lastModified: '1970-01-01T00:00:00Z',
          name: ''
        }
      }
    end
  end
end

RSpec.describe 'Atlassian Crowd' do
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
