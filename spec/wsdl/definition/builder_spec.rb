# frozen_string_literal: true

RSpec.describe WSDL::Definition::Builder do
  subject(:definition) { WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock) }

  describe '#build' do
    it 'returns a frozen Definition' do
      expect(definition).to be_a(WSDL::Definition)
      expect(definition).to be_frozen
    end

    it 'stores schema_version' do
      expect(definition.schema_version).to eq(described_class::SCHEMA_VERSION)
    end

    it 'uses schema version 2' do
      expect(definition.schema_version).to eq(2)
    end

    it 'stores service_name' do
      expect(definition.service_name).to eq('AuthenticationWebServiceImplService')
    end

    it 'stores fingerprint' do
      expect(definition.fingerprint).to match(/\Asha256:[a-f0-9]{64}\z/)
    end

    it 'stores sources from provenance' do
      expect(definition.sources).not_to be_empty
      expect(definition.sources.first[:status]).to eq('resolved')
    end

    it 'produces stable fingerprints for the same input' do
      definition_a = WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock)
      definition_b = WSDL::Parser.parse(fixture('wsdl/authentication'), http_mock)

      expect(definition_a.fingerprint).to eq(definition_b.fingerprint)
    end
  end

  describe 'services structure' do
    it 'builds service data' do
      data = definition.to_h
      services = data['services']

      expect(services).to have_key('AuthenticationWebServiceImplService')
      expect(services['AuthenticationWebServiceImplService']).to have_key('ports')
    end

    it 'builds port data with endpoint' do
      port = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort')

      expect(port['endpoint']).to eq('http://example.com/validation/1.0/AuthenticationService')
      expect(port['type']).to eq('http://schemas.xmlsoap.org/wsdl/soap/')
    end

    it 'builds operation data' do
      operations = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations')

      expect(operations).to have_key('authenticate')
      op = operations['authenticate']
      expect(op['name']).to eq('authenticate')
      expect(op['input_style']).to eq('document/literal')
    end
  end

  describe 'operation element hashes' do
    it 'converts input body elements to hashes' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      input_body = op.dig('input', 'body')
      expect(input_body).to be_an(Array)
      expect(input_body).not_to be_empty
      expect(input_body.first).to have_key('name')
      expect(input_body.first).to have_key('type')
    end

    it 'converts output body elements to hashes' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      output_body = op.dig('output', 'body')
      expect(output_body).to be_an(Array)
    end

    it 'converts input header elements to hashes' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      input_header = op.dig('input', 'header')
      expect(input_header).to be_an(Array)
    end
  end

  describe 'schema_complete' do
    it 'pre-computes schema_complete for operations' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      expect(op).to have_key('schema_complete')
      expect(op['schema_complete']).to be(true)
    end

    it 'sets schema_complete to false when imports fail' do
      juniper_def = WSDL::Parser.parse(fixture('wsdl/juniper'), http_mock,
        strictness: WSDL::Strictness.off)

      op = juniper_def.to_h.dig('services', 'SystemService', 'ports', 'System',
        'operations', 'LoginRequest')
      expect(op['schema_complete']).to be(false)
    end
  end

  describe 'multi-operation WSDLs' do
    subject(:definition) { WSDL::Parser.parse(fixture('wsdl/interhome'), http_mock) }

    it 'builds all operations' do
      port_data = definition.to_h.dig('services', 'WebService', 'ports', 'WebServiceSoap')
      operations = port_data['operations']

      expect(operations.keys.size).to be > 1
    end
  end

  describe 'serialization round-trip' do
    it 'round-trips through to_h and from_h' do
      hash = definition.to_h
      restored = WSDL::Definition.from_h(hash)

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
      expect(restored.sources.size).to eq(definition.sources.size)
      expect(restored.to_h).to eq(hash)
    end

    it 'round-trips through JSON' do
      json = definition.to_json
      hash = JSON.parse(json)
      restored = WSDL::Definition.from_h(hash)

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
    end

    it 'raises on non-Hash input' do
      expect {
        WSDL::Definition.from_h('spec/fixtures/wsdl/economic.wsdl')
      }.to raise_error(ArgumentError, /Expected a Hash.*got String/)
    end

    it 'raises on schema version mismatch' do
      hash = definition.to_h
      hash['schema_version'] = 999

      expect {
        WSDL::Definition.from_h(hash)
      }.to raise_error(ArgumentError, /schema version mismatch/)
    end

    it 'rejects schema version 1' do
      hash = definition.to_h
      hash['schema_version'] = 1

      expect {
        WSDL::Definition.from_h(hash)
      }.to raise_error(ArgumentError, /schema version mismatch.*re-parse/m)
    end

    it 'preserves element type strings through round-trip' do
      json = definition.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))
      op = restored.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      body_elements = op.dig('input', 'body')
      types = collect_types(body_elements)
      expect(types).to all(be_a(String))
      expect(types).to all(match(/\A(simple|complex|recursive)\z/))
    end

    it 'preserves provenance status strings through round-trip' do
      json = definition.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))

      statuses = restored.sources.map { |s| s[:status] }
      expect(statuses).to all(be_a(String))
      expect(statuses).to all(match(/\A(resolved|failed)\z/))
    end

    it 'preserves unbounded max_occurs through round-trip' do
      bronto_def = WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock)
      json = bronto_def.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))

      expect(restored.to_h).to eq(bronto_def.to_h)
    end

    it 'does not corrupt element names that match type keywords' do
      # Verify that element names like "simple", "complex", etc.
      # are not incorrectly converted to symbols during deserialization
      json = definition.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))
      op = restored.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      names = collect_names(op.dig('input', 'body'))
      expect(names).to all(be_a(String))
    end
  end

  describe 'builds from various fixtures' do
    %w[authentication temperature blz_service bronto].each do |fixture_name|
      it "builds and round-trips #{fixture_name}" do
        defn = WSDL::Parser.parse(fixture("wsdl/#{fixture_name}"), http_mock)

        expect(defn).to be_frozen
        expect(defn.to_h['services']).not_to be_empty
        expect(defn.fingerprint).to match(/\Asha256:/)

        # Full JSON round-trip
        restored = WSDL::Definition.from_h(JSON.parse(defn.to_json))
        expect(restored.to_h).to eq(defn.to_h)
      end
    end
  end

  describe 'build_operations edge cases' do
    let(:tempfiles) { [] }

    after do
      tempfiles.each(&:close!)
    end

    def write_wsdl_file(wsdl_xml)
      file = Tempfile.new(['builder-spec', '.wsdl'])
      file.write(wsdl_xml)
      file.flush
      tempfiles << file
      file.path
    end

    def parse_definition(wsdl_xml)
      WSDL::Parser.parse(write_wsdl_file(wsdl_xml), http_mock)
    end

    describe 'binding operation not in portType' do
      subject(:definition) do
        parse_definition(<<~XML)
          <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                       xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                       xmlns:tns="http://t.com" targetNamespace="http://t.com">
            <portType name="PT"/>
            <binding name="B" type="tns:PT">
              <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
              <operation name="GhostOp">
                <soap:operation soapAction="ghost"/>
                <input><soap:body use="literal"/></input>
                <output><soap:body use="literal"/></output>
              </operation>
            </binding>
            <service name="S">
              <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
            </service>
          </definitions>
        XML
      end

      it 'records a build issue referencing the portType' do
        expect(definition.build_issues).to contain_exactly(
          a_hash_including(type: :build_error, operation: 'GhostOp')
        )
        expect(definition.build_issues.first[:error]).to include('portType')
      end

      it 'stores the operation with default metadata' do
        op = definition.operation_data('S', 'P', 'GhostOp')

        expect(op[:name]).to eq('GhostOp')
        expect(op[:soap_action]).to be_nil
        expect(op[:input_style]).to be_nil
        expect(op[:input]).to eq(header: [], body: [])
        expect(op[:output]).to be_nil
      end
    end

    describe 'binding operation missing input element' do
      subject(:definition) do
        parse_definition(<<~XML)
          <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                       xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                       xmlns:tns="http://t.com" targetNamespace="http://t.com">
            <portType name="PT"><operation name="Op"/></portType>
            <binding name="B" type="tns:PT">
              <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
              <operation name="Op"><soap:operation soapAction="DoStuff"/></operation>
            </binding>
            <service name="S">
              <port name="P" binding="tns:B"><soap:address location="http://x.com"/></port>
            </service>
          </definitions>
        XML
      end

      it 'records a build issue about missing input' do
        expect(definition.build_issues).to include(
          a_hash_including(
            type: :build_error,
            operation: 'Op',
            error: a_string_matching(/missing a required.*input/i)
          )
        )
      end

      it 'populates soap_action and soap_version but not styles' do
        op = definition.operation_data('S', 'P', 'Op')

        expect(op[:soap_action]).to eq('DoStuff')
        expect(op[:soap_version]).to eq('1.1')
        expect(op[:input_style]).to be_nil
        expect(op[:output_style]).to be_nil
      end
    end

    describe 'overloaded operations' do
      subject(:definition) do
        WSDL::Parser.parse(fixture('parser/operation_overloading'), http_mock)
      end

      it 'stores overloaded operations as an array' do
        ops = definition.to_h.dig('services', 'LookupService', 'ports', 'LookupPort', 'operations')
        lookup = ops['Lookup']

        expect(lookup).to be_an(Array)
        expect(lookup.size).to eq(2)
        expect(lookup.map { |o| o['input_name'] }).to contain_exactly('LookupById', 'LookupByName')
      end

      it 'assigns distinct metadata to each overload' do
        by_id = definition.operation_data('LookupService', 'LookupPort', 'Lookup', input_name: 'LookupById')
        by_name = definition.operation_data('LookupService', 'LookupPort', 'Lookup', input_name: 'LookupByName')

        expect(by_id[:soap_action]).to eq('LookupById')
        expect(by_name[:soap_action]).to eq('LookupByName')
        expect(by_id[:input][:body]).not_to eq(by_name[:input][:body])
      end
    end

    describe 'unresolved binding reference' do
      subject(:definition) do
        WSDL::Parser.parse(fixture('parser/unresolved_references/binding'), http_mock)
      end

      it 'records a build issue with nil operation' do
        expect(definition.build_issues).to include(
          a_hash_including(type: :build_error, operation: nil)
        )
      end

      it 'returns empty operations for the affected port' do
        port = definition.to_h.dig('services', 'BadService', 'ports', 'BadPort')

        expect(port['operations']).to be_empty
      end
    end
  end

  private

  def collect_types(elements)
    elements.flat_map do |el|
      [el['type']] + collect_types(el['children'] || [])
    end
  end

  def collect_names(elements)
    elements.flat_map do |el|
      [el['name']] + collect_names(el['children'] || [])
    end
  end
end
