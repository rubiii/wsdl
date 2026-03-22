# frozen_string_literal: true

RSpec.describe 'RPC/Literal example' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:rpc_literal] }
  let(:service_name) { :SampleService }
  let(:port_name)    { :Sample }

  before do
    service.start
  end

  it 'routes op1 and returns the correct response' do
    operation = client.operation(service_name, port_name, :op1)

    operation.prepare do
      body do
        tag('in') do
          tag('data1', 24)
          tag('data2', 36)
        end
      end
    end
    response = operation.invoke

    # RPC/literal responses are parsed without schema-aware type coercion
    # because the op1Response RPC wrapper is not a schema element.
    expect(response.body).to eq(
      op1Response: {
        op1Return: { data1: '48', data2: '72' }
      }
    )
  end

  it 'routes op2 separately from op1' do
    operation = client.operation(service_name, port_name, :op2)

    operation.prepare do
      body do
        tag('in') do
          tag('data1', 1)
          tag('data2', 2)
        end
      end
    end
    response = operation.invoke

    expect(response.body).to eq(
      op2Response: {
        op2Return: { data1: '3', data2: '4' }
      }
    )
  end
end
