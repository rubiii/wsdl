# frozen_string_literal: true

RSpec.describe WSDL::Operation do
  let(:client) { WSDL::Client.new(fixture('wsdl/temperature'), strictness: WSDL::Strictness.off) }
  let(:operation) { client.operation('ConvertTemperature', 'ConvertTemperatureSoap12', 'ConvertTemp') }

  describe '#contract' do
    it 'returns request and response message contracts' do
      contract = operation.contract

      expect(contract.request).to be_a(WSDL::Contract::MessageContract)
      expect(contract.response).to be_a(WSDL::Contract::MessageContract)
      expect(contract.style).to eq('document/literal')
    end

    it 'exposes path metadata for request body' do
      paths = operation.contract.request.body.paths

      expect(paths.first[:path]).to eq(['ConvertTemp'])
      expect(paths.first[:namespace]).to eq('http://www.webserviceX.NET/')
      expect(paths.first[:form]).to eq('qualified')
    end

    it 'exposes hierarchical tree metadata for request body' do
      tree = operation.contract.request.body.tree

      expect(tree.first[:name]).to eq('ConvertTemp')
      expect(tree.first[:children].map { |child| child[:name] }).to eq(%w[Temperature FromUnit ToUnit])
    end

    it 'builds template guidance in minimal mode' do
      template = operation.contract.request.body.template(mode: :minimal)

      expect(template.to_h).to eq(
        ConvertTemp: {
          Temperature: 'double',
          FromUnit: 'string',
          ToUnit: 'string'
        }
      )

      dsl = template.to_dsl
      expect(dsl).to include('operation.prepare do')
      expect(dsl).to include("tag('ConvertTemp')")
      # Body content should not be wrapped in explicit `body do` block
      expect(dsl).not_to include('body do')
      # Elements should be at 2-space indentation (top-level), not 4-space
      expect(dsl).to include("  tag('ConvertTemp')")
    end

    it 'builds template guidance for header with explicit wrapper' do
      template = operation.contract.request.header.template(mode: :minimal)

      dsl = template.to_dsl
      expect(dsl).to include('operation.prepare do')
      # Header content SHOULD be wrapped in explicit `header do` block
      expect(dsl).to include('header do')
    end

    it 'builds template in full mode including optional elements' do
      template = operation.contract.request.body.template(mode: :full)

      hash = template.to_h
      expect(hash).to have_key(:ConvertTemp)

      dsl = template.to_dsl
      expect(dsl).to include('operation.prepare do')
    end

    it 'raises ArgumentError for invalid template mode' do
      expect {
        operation.contract.request.body.template(mode: :unknown)
      }.to raise_error(ArgumentError, /Invalid template mode/)
    end

    it 'reports empty? for message contracts without elements' do
      empty_part = operation.contract.request.header
      contract = WSDL::Contract::MessageContract.new(header: empty_part, body: empty_part)

      expect(contract.empty?).to be true
    end

    it 'includes attributes in tree view' do
      tree = operation.contract.request.body.tree

      # Walk the tree looking for any element that has attributes
      # If none have attributes, at least verify the structure works
      visit = lambda { |nodes|
        nodes.each do |node|
          expect(node).to have_key(:attributes)
          expect(node[:attributes]).to be_an(Array)
          visit.call(node[:children]) if node[:children]
        end
      }
      visit.call(tree)
    end
  end
end
