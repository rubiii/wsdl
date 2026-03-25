# frozen_string_literal: true

RSpec.describe 'Split namespace imports' do
  subject(:definition) { WSDL.parse fixture('wsdl/split_namespace/service.wsdl') }

  it 'resolves elements from both schemas sharing a namespace' do
    expect(definition.build_issues).to be_empty
  end

  it 'resolves input elements from the first schema' do
    input = definition.input('GetUser')
    expect(input.first[:name]).to eq('GetUserRequest')
    expect(input.first[:children].map { |c| c[:name] }).to eq(['userId'])
  end

  it 'resolves output elements from the second schema' do
    output = definition.output('GetUser')
    expect(output.first[:name]).to eq('GetUserResponse')
    expect(output.first[:children].map { |c| c[:name] }).to eq(%w[name email])
  end
end
