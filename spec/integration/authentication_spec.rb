# frozen_string_literal: true

WSDL::TestService.define(:authentication, wsdl: 'wsdl/authentication') do
  operation :authenticate do
    on user: 'admin', password: 'secret' do
      {
        return: {
          authenticationValue: {
            token: 'a68d1c97-00e4-4caf-a8d0-1d3b08ee5d3b',
            tokenHash: 'a1b2c3d4e5f6',
            client: 'admin-console'
          },
          success: true
        }
      }
    end

    on user: 'admin', password: 'wrong' do
      {
        return: {
          success: false
        }
      }
    end
  end
end

RSpec.describe 'Authentication service' do
  subject(:client) { WSDL::Client.new(service.wsdl_url) }

  let(:service) { WSDL::TestService[:authentication] }
  let(:service_name) { :AuthenticationWebServiceImplService }
  let(:port_name) { :AuthenticationWebServiceImplPort }

  before do
    service.start
  end

  it 'returns a token on successful authentication' do
    operation = client.operation(service_name, port_name, :authenticate)

    operation.prepare do
      body do
        tag('authenticate') do
          tag('user', 'admin')
          tag('password', 'secret')
        end
      end
    end
    response = operation.invoke
    result = response.body[:authenticateResponse][:return]

    expect(result[:success]).to be true
    expect(result[:authenticationValue][:token]).to eq('a68d1c97-00e4-4caf-a8d0-1d3b08ee5d3b')
    expect(result[:authenticationValue][:client]).to eq('admin-console')
  end

  it 'returns failure on wrong password' do
    operation = client.operation(service_name, port_name, :authenticate)

    operation.prepare do
      body do
        tag('authenticate') do
          tag('user', 'admin')
          tag('password', 'wrong')
        end
      end
    end
    response = operation.invoke
    result = response.body[:authenticateResponse][:return]

    expect(result[:success]).to be false
    expect(result[:authenticationValue]).to be_nil
  end
end
