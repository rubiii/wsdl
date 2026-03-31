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
      expect(definition.sources.first['status']).to eq('resolved')
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

      namespaces = definition.to_h['namespaces']
      expect(namespaces[port['type']]).to eq('http://schemas.xmlsoap.org/wsdl/soap/')
    end

    it 'builds operation data' do
      op = definition.operation_data('AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort', 'authenticate')

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
      op = definition.operation_data('AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort', 'authenticate')

      expect(op).to have_key('schema_complete')
      expect(op['schema_complete']).to be(true)
    end

    it 'sets schema_complete to false when imports fail' do
      juniper_def = WSDL::Parser.parse(fixture('wsdl/juniper'), http_mock,
        strictness: WSDL::Strictness.off)

      op = juniper_def.operation_data('SystemService', 'System', 'LoginRequest')
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
      restored = WSDL::Definition.from_h(definition.to_h)

      expect(restored.service_name).to eq(definition.service_name)
      expect(restored.fingerprint).to eq(definition.fingerprint)
      expect(restored.sources.size).to eq(definition.sources.size)
      expect(restored.to_h).to eq(definition.to_h)
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
      hash = definition.to_h.dup
      hash['schema_version'] = 999

      expect {
        WSDL::Definition.from_h(hash)
      }.to raise_error(WSDL::SchemaVersionError, /schema version mismatch/)
    end

    it 'rejects schema version 1' do
      hash = definition.to_h.dup
      hash['schema_version'] = 1

      expect {
        WSDL::Definition.from_h(hash)
      }.to raise_error(WSDL::SchemaVersionError, /schema version mismatch.*re-parse/m)
    end

    it 'exposes expected and actual versions on SchemaVersionError' do
      hash = definition.to_h.dup
      hash['schema_version'] = 999

      error = begin
        WSDL::Definition.from_h(hash)
      rescue WSDL::SchemaVersionError => e
        e
      end

      expect(error.expected_version).to eq(WSDL::Definition::Builder::SCHEMA_VERSION)
      expect(error.actual_version).to eq(999)
    end

    it 'preserves element type strings through round-trip' do
      json = definition.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))
      op = restored.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      body_elements = op.dig('input', 'body')
      type_registry = restored.to_h['types'] || {}
      types = collect_types(body_elements, types: type_registry)
      expect(types).to all(be_a(String))
      expect(types).to all(match(/\A(simple|complex|recursive)\z/))
    end

    it 'preserves provenance status strings through round-trip' do
      json = definition.to_json
      restored = WSDL::Definition.from_h(JSON.parse(json))

      statuses = restored.sources.map { |s| s['status'] }
      expect(statuses).to all(be_a(String))
      expect(statuses).to all(match(/\A(resolved|failed)\z/))
    end

    it 'supports operation_data lookup after from_h round-trip' do
      restored = WSDL::Definition.from_h(JSON.parse(definition.to_json))
      op = restored.operation_data(
        'AuthenticationWebServiceImplService',
        'AuthenticationWebServiceImplPort',
        'authenticate'
      )

      expect(op['name']).to eq('authenticate')
      expect(op['input']['body']).to be_an(Array)
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

      type_registry = restored.to_h['types'] || {}
      names = collect_names(op.dig('input', 'body'), types: type_registry)
      expect(names).to all(be_a(String))
    end
  end

  describe 'lean element hashes' do
    it 'omits singular key from all element hashes' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      type_registry = definition.to_h['types'] || {}
      all_elements = collect_all_elements(op.dig('input', 'body'), types: type_registry)
      all_elements.each do |el|
        expect(el).not_to have_key('singular'), "Element #{el['name']} should not have 'singular' key"
      end
    end

    it 'omits default-valued fields from simple leaf elements' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      type_registry = definition.to_h['types'] || {}
      leaf = find_leaf_element(op.dig('input', 'body'), types: type_registry)
      expect(leaf).not_to be_nil, 'Expected at least one simple leaf element'
      expect(leaf).not_to have_key('nillable')
      expect(leaf).not_to have_key('list')
      expect(leaf).not_to have_key('any_content')
      expect(leaf).not_to have_key('recursive_type')
      expect(leaf).not_to have_key('complex_type_id')
    end

    it 'does not produce "Infinity" in serialized output' do
      bronto_def = WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock)
      json = bronto_def.to_json

      expect(json).not_to include('"Infinity"')
    end

    it 'uses "unbounded" for unbounded max_occurs' do
      bronto_def = WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock)
      json = bronto_def.to_json

      expect(json).to include('"unbounded"')
    end

    it 'shortens element namespace key to "ns"' do
      op = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort', 'operations', 'authenticate')

      type_registry = definition.to_h['types'] || {}
      all_elements = collect_all_elements(op.dig('input', 'body'), types: type_registry)
      expect(all_elements).not_to be_empty

      all_elements.each do |el|
        expect(el).to have_key('ns'), "Element #{el['name']} should have 'ns' key"
        expect(el).not_to have_key('namespace'), "Element #{el['name']} should not have 'namespace' key"
      end
    end

    it 'shortens min_occurs key to "min"' do
      bronto_def = WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock)
      json = bronto_def.to_json

      expect(json).not_to include('"min_occurs"')
    end

    it 'shortens max_occurs key to "max"' do
      bronto_def = WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock)
      json = bronto_def.to_json

      expect(json).not_to include('"max_occurs"')
    end
  end

  describe 'namespace table' do
    it 'includes a namespaces array in to_h' do
      namespaces = definition.to_h['namespaces']

      expect(namespaces).to be_an(Array)
      expect(namespaces).not_to be_empty
      expect(namespaces).to all(be_a(String))
    end

    it 'resolves namespace indices to correct URIs via port_type' do
      namespaces = definition.to_h['namespaces']
      port = definition.to_h.dig('services', 'AuthenticationWebServiceImplService', 'ports',
        'AuthenticationWebServiceImplPort')

      expect(namespaces[port['type']]).to eq('http://schemas.xmlsoap.org/wsdl/soap/')
    end

    it 'resolves namespace indices to URI strings via operation_data' do
      op = definition.operation_data('authenticate')
      element = WSDL::Definition::Element.new(op['input']['body'].first)

      expect(element.namespace).to be_a(String)
      expect(element.namespace).to include('://')
    end

    it 'resolves RPC namespace indices to URI strings via operation_data' do
      rpc_def = WSDL::Parser.parse(fixture('wsdl/rpc_literal'), http_mock)
      op = rpc_def.operation_data('SampleService', 'Sample', 'op1')

      expect(op['rpc_input_namespace']).to be_a(String)
      expect(op['rpc_input_namespace']).to eq('http://apiNamespace.com')
    end

    it 'round-trips RPC namespace values through from_h' do
      jira_def = WSDL::Parser.parse(fixture('wsdl/jira'), http_mock)
      restored = WSDL::Definition.from_h(JSON.parse(jira_def.to_json))

      expect(restored.to_h).to eq(jira_def.to_h)
    end
  end

  describe 'port extension' do
    context 'with blz_service fixture' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/blz_service'), http_mock) }

      it 'second port has extends reference in to_h' do
        ports = definition.to_h.dig('services', 'BLZService', 'ports')
        port_names = ports.keys

        first_port = ports[port_names.first]
        second_port = ports[port_names.last]

        expect(first_port).to have_key('operations')
        expect(first_port).not_to have_key('extends')

        expect(second_port).to have_key('extends')
        expect(second_port['extends']).to eq(port_names.first)
        expect(second_port).not_to have_key('operations')
      end

      it 'operation_data works on extended port after from_h' do
        restored = WSDL::Definition.from_h(JSON.parse(definition.to_json))
        ports = restored.to_h.dig('services', 'BLZService', 'ports')
        extended_port_name = ports.keys.find { |name| ports[name].key?('extends') }

        op = restored.operation_data('BLZService', extended_port_name, 'getBank')
        expect(op['name']).to eq('getBank')
        expect(op['input']['body']).to be_an(Array)
      end

      it 'ports() returns correct endpoints for all ports' do
        ports = definition.ports
        expect(ports.size).to eq(2)
        ports.each do |port|
          expect(port[:endpoint]).to be_a(String)
          expect(port[:endpoint]).to include('http')
        end
      end

      it 'operations() lists operations from all ports including extended' do
        ops = definition.operations
        expect(ops.size).to eq(2)
        expect(ops.map { |o| o[:port] }.uniq.size).to eq(2)
      end
    end

    context 'with corrupt extends reference' do
      it 'handles corrupt extends reference gracefully' do
        base = definition.to_h.dup
        services = JSON.parse(JSON.generate(base['services']))

        # Inject a bogus extends reference
        svc = services.values.first
        svc['ports']['BogusPort'] = {
          'type' => 0, 'endpoint' => 'http://bogus',
          'extends' => 'NonExistentPort'
        }

        corrupt_def = WSDL::Definition.from_h(base.merge('services' => services))

        # Should not crash — port should be accessible but with no operations
        ports = corrupt_def.ports
        bogus = ports.find { |p| p[:name] == 'BogusPort' }
        expect(bogus).not_to be_nil
        expect(bogus[:endpoint]).to eq('http://bogus')
      end
    end

    context 'with oracle fixture' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/oracle'), http_mock) }

      it 'no port has extends reference' do
        definition.to_h['services'].each_value do |svc|
          svc['ports'].each_value do |port|
            expect(port).not_to have_key('extends')
            expect(port).to have_key('operations')
          end
        end
      end
    end
  end

  describe 'builds and round-trips from various fixtures' do
    %w[authentication temperature blz_service bronto jira].each do |fixture_name|
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

  describe 'fixture round-trip validation' do
    fixture_dir = File.expand_path('../../fixtures/wsdl', __dir__)

    Dir.glob(File.join(fixture_dir, '*.wsdl')).each do |path|
      fixture_name = File.basename(path, '.wsdl')

      it "round-trips #{fixture_name} through JSON" do
        defn = WSDL::Parser.parse(path, http_mock, limits: WSDL::Limits.new(max_schemas: nil))
        json = defn.to_json
        restored = WSDL::Definition.from_h(JSON.parse(json, max_nesting: WSDL::Definition::MAX_JSON_NESTING))

        expect(restored.to_h).to eq(defn.to_h)
      rescue WSDL::SchemaImportError
        skip "#{fixture_name} requires external schema imports"
      end
    end
  end

  describe 'serialization constraints' do
    let(:relaxed_limits) { WSDL::Limits.new(max_schemas: nil) }

    it 'serializes awse.wsdl without JSON nesting errors' do
      defn = WSDL::Parser.parse(fixture('wsdl/awse'), http_mock, limits: relaxed_limits)

      expect { defn.to_json }.not_to raise_error

      restored = WSDL::Definition.from_h(JSON.parse(defn.to_json, max_nesting: WSDL::Definition::MAX_JSON_NESTING))
      expect(restored.to_h).to eq(defn.to_h)
    end

    it 'limits element nesting depth after element-ref recursion fix' do
      defn = WSDL::Parser.parse(fixture('wsdl/awse'), http_mock, limits: relaxed_limits)
      data = defn.to_h

      # Recursively measure the maximum depth of inline element children.
      # Only counts 'children' arrays (inline nesting), not type_ref pointers.
      measure_depth = lambda { |elements, depth|
        return depth if elements.nil? || elements.empty?

        elements.filter_map { |el|
          children = el['children']
          measure_depth.call(children, depth + 1) if children && !children.empty?
        }.max || depth
      }

      # Walk all services -> ports -> operations -> input/output -> body/header
      max_depth = 0
      data['services'].each_value do |svc|
        ports = svc['ports']
        ports.each_value do |port_data|
          ops = port_data['operations']
          ops ||= ports.dig(port_data['extends'], 'operations') if port_data['extends']
          next unless ops

          ops.each_value do |op|
            entries = op.is_a?(Array) ? op : [op]
            entries.each do |entry|
              %w[input output].each do |direction|
                msg = entry[direction]
                next unless msg

                %w[body header].each do |section|
                  elements = msg[section]
                  next unless elements

                  depth = measure_depth.call(elements, 1)
                  max_depth = depth if depth > max_depth
                end
              end
            end
          end
        end
      end

      # Before the element-ref recursion fix, AWSE reached ~110 levels of nesting
      # because the Item -> RelatedItems -> RelatedItem -> Item cycle repeated ~16x.
      # After the fix, the cycle is detected on first re-encounter.
      expect(max_depth).to be < 30
    end

    it 'keeps economic.wsdl v2 JSON under 1,500,000 bytes' do
      defn = WSDL::Parser.parse(fixture('wsdl/economic'), http_mock, limits: relaxed_limits)
      json = defn.to_json

      expect(json.size).to be < 1_500_000
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
          a_hash_including('type' => 'build_error', 'operation' => 'GhostOp')
        )
        expect(definition.build_issues.first['error']).to include('portType')
      end

      it 'stores the operation with default metadata' do
        op = definition.operation_data('S', 'P', 'GhostOp')

        expect(op['name']).to eq('GhostOp')
        expect(op['soap_action']).to be_nil
        expect(op['input_style']).to be_nil
        expect(op['input']).to eq('header' => [], 'body' => [])
        expect(op['output']).to be_nil
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
            'type' => 'build_error',
            'operation' => 'Op',
            'error' => a_string_matching(/missing a required.*input/i)
          )
        )
      end

      it 'populates soap_action and soap_version but not styles' do
        op = definition.operation_data('S', 'P', 'Op')

        expect(op['soap_action']).to eq('DoStuff')
        expect(op['soap_version']).to eq('1.1')
        expect(op['input_style']).to be_nil
        expect(op['output_style']).to be_nil
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

        expect(by_id['soap_action']).to eq('LookupById')
        expect(by_name['soap_action']).to eq('LookupByName')
        expect(by_id['input']['body']).not_to eq(by_name['input']['body'])
      end
    end

    describe 'unresolved binding reference' do
      subject(:definition) do
        WSDL::Parser.parse(fixture('parser/unresolved_references/binding'), http_mock)
      end

      it 'records a build issue with nil operation' do
        expect(definition.build_issues).to include(
          a_hash_including('type' => 'build_error', 'operation' => nil)
        )
      end

      it 'returns empty operations for the affected port' do
        port = definition.to_h.dig('services', 'BadService', 'ports', 'BadPort')

        expect(port['operations']).to be_empty
      end
    end
  end

  describe 'type registry' do
    it 'includes a types hash in to_h' do
      data = definition.to_h

      expect(data).to have_key('types')
      expect(data['types']).to be_a(Hash)
    end

    it 'uses nsIndex:localName format for type keys' do
      type_registry = definition.to_h['types']
      type_keys = type_registry.keys.reject { |k| k.start_with?('_') }

      expect(type_keys).not_to be_empty
      expect(type_keys).to all(match(/\A\d+:.+\z/))
    end

    it 'typed elements have type_ref without children or complex_type_id' do
      data = definition.to_h
      all_elements = walk_all_elements_in_to_h(data)

      typed_elements = all_elements.select { |el| el.key?('type_ref') }
      expect(typed_elements).not_to be_empty

      typed_elements.each do |el|
        expect(el).not_to have_key('children'),
          "Element #{el['name']} has type_ref but also has children"
        expect(el).not_to have_key('attributes'),
          "Element #{el['name']} has type_ref but also has attributes"
        expect(el).not_to have_key('complex_type_id'),
          "Element #{el['name']} has type_ref but also has complex_type_id"
      end
    end

    it 'type registry entries have children' do
      type_registry = definition.to_h['types']

      entries_with_children = type_registry.values.select { |entry| entry['children']&.any? }
      expect(entries_with_children).not_to be_empty
    end

    it 'complex elements have either type_ref or inline children' do
      data = definition.to_h
      all_elements = walk_all_elements_in_to_h(data)

      complex_elements = all_elements.select { |el| el['type'] == 'complex' }
      complex_elements.each do |el|
        has_ref = el.key?('type_ref')
        has_children = el.key?('children')

        expect(has_ref || has_children).to be(true),
          "Complex element #{el['name']} has neither type_ref nor children"
        expect(has_ref && has_children).to be(false),
          "Complex element #{el['name']} has both type_ref and children"
      end
    end

    context 'with bronto fixture' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock) }

      it 'deduplicates shared types' do
        data = definition.to_h
        type_registry = data['types']
        all_elements = walk_all_elements_in_to_h(data)

        typed_elements = all_elements.select { |el| el.key?('type_ref') }

        # Count how many elements share each type_ref value
        ref_counts = typed_elements.group_by { |el| el['type_ref'] }
        shared_refs = ref_counts.select { |_, els| els.size > 1 }

        expect(shared_refs).not_to be_empty,
          'Expected at least one type_ref shared by multiple elements'
        expect(type_registry.size).to be < typed_elements.size,
          'Expected fewer registry entries than total typed elements'
      end

      it 'type registry entries reference existing types for nested type_refs' do
        type_registry = definition.to_h['types']

        nested_refs = type_registry.values.flat_map { |entry|
          (entry['children'] || []).select { |c| c.key?('type_ref') }
        }

        expect(nested_refs).not_to be_empty,
          'Expected bronto to have nested type_refs in registry entries'

        nested_refs.each do |child|
          expect(type_registry).to have_key(child['type_ref']),
            "Nested type_ref #{child['type_ref'].inspect} not found in registry"
        end
      end
    end

    it 'consumer sees expanded children after type_ref resolution' do
      op = definition.operation_data('authenticate')
      body = op['input']['body']

      # The top-level authenticate element should have children, not type_ref
      authenticate_el = body.first
      expect(authenticate_el['name']).to eq('authenticate')
      expect(authenticate_el).to have_key('children')
      expect(authenticate_el['children'].size).to eq(2)

      # Recursively verify no type_ref appears anywhere
      assert_no_type_ref(body)
    end

    it 'input returns correct developer view with type expansion' do
      result = definition.input('authenticate')

      expect(result).not_to be_empty
      expect(result.first[:name]).to eq('authenticate')
      expect(result.first[:children]).to be_an(Array)
      expect(result.first[:children].size).to eq(2)
      expect(result.first[:children].map { |c| c[:name] }).to contain_exactly('user', 'password')
    end

    context 'with bronto round-trip' do
      subject(:definition) { WSDL::Parser.parse(fixture('wsdl/bronto'), http_mock) }

      it 'round-trips through JSON with type registry' do
        json = definition.to_json
        restored = WSDL::Definition.from_h(JSON.parse(json))

        expect(restored.to_h).to eq(definition.to_h)
        expect(restored.to_h['types']).to eq(definition.to_h['types'])
      end

      it 'operation_data works after round-trip' do
        restored = WSDL::Definition.from_h(JSON.parse(definition.to_json))

        op = restored.operation_data('BrontoSoapApiImplService', 'BrontoSoapApiImplPort', 'login')
        expect(op['name']).to eq('login')
        expect(op['input']['body']).to be_an(Array)
        assert_no_type_ref(op['input']['body'])
      end
    end

    context 'with recursive types fixture' do
      subject(:definition) { WSDL::Parser.parse(fixture('parser/recursive_types'), http_mock) }

      it 'expands type_ref without stack overflow on recursive types' do
        op = definition.operation_data('TreeService', 'TreePort', 'GetTree')
        body = op['output']['body']

        # GetTreeResponse should have expanded children
        response_el = body.first
        expect(response_el['name']).to eq('GetTreeResponse')
        expect(response_el).to have_key('children')

        # Find the recursive boundary — walk until we hit type='recursive'
        node_el = response_el['children'].find { |c| c['name'] == 'node' }
        expect(node_el).to have_key('children')

        children_el = node_el['children'].find { |c| c['name'] == 'children' }
        expect(children_el).not_to be_nil
        expect(children_el['type']).to eq('recursive')
        expect(children_el['recursive_type']).to eq('tns:TreeNode')

        # No type_ref should remain anywhere in the expanded tree
        assert_no_type_ref(body)
      end

      it 'stores _recursive_labels in the type registry' do
        types = definition.to_h['types']

        expect(types).to have_key('_recursive_labels')
        labels = types['_recursive_labels']
        expect(labels).to be_a(Hash)
        expect(labels.values).to include('tns:TreeNode')
      end

      it 'round-trips _recursive_labels through JSON' do
        json = definition.to_json
        restored = WSDL::Definition.from_h(JSON.parse(json))

        expect(restored.to_h['types']['_recursive_labels']).to eq(definition.to_h['types']['_recursive_labels'])
      end
    end

    context 'with element ref recursion fixture' do
      subject(:definition) { WSDL::Parser.parse(fixture('parser/element_ref_recursion'), http_mock) }

      it 'expands type_ref without stack overflow on element-ref cycles' do
        op = definition.operation_data('ItemService', 'ItemPort', 'GetItem')
        body = op['output']['body']

        response_el = body.first
        expect(response_el['name']).to eq('GetItemResponse')
        expect(response_el).to have_key('children')

        # Walk to the recursive boundary: GetItemResponse > Item > RelatedItems > Item
        item_el = response_el['children'].find { |c| c['name'] == 'Item' }
        expect(item_el).to have_key('children')

        related_el = item_el['children'].find { |c| c['name'] == 'RelatedItems' }
        expect(related_el).to have_key('children')

        recursive_item = related_el['children'].find { |c| c['name'] == 'Item' }
        expect(recursive_item).not_to be_nil
        expect(recursive_item['type']).to eq('recursive')
        expect(recursive_item['recursive_type']).to eq('tns:Item')

        assert_no_type_ref(body)
      end

      it 'round-trips through JSON' do
        json = definition.to_json
        restored = WSDL::Definition.from_h(JSON.parse(json))

        expect(restored.to_h).to eq(definition.to_h)
      end

      it 'stores _recursive_labels in the type registry' do
        types = definition.to_h['types']

        expect(types).to have_key('_recursive_labels')
        labels = types['_recursive_labels']
        expect(labels.values).to include('tns:Item')
      end
    end

    context 'with missing type_ref in registry' do
      it 'handles corrupt type_ref gracefully without crashing' do
        # Build a minimal valid definition with a bogus type_ref
        base = definition.to_h.dup
        services = JSON.parse(JSON.generate(base['services']))

        # Inject a bogus type_ref into the authenticate operation's input body
        op = services.dig(
          'AuthenticationWebServiceImplService', 'ports',
          'AuthenticationWebServiceImplPort', 'operations', 'authenticate'
        )
        op['input']['body'] = [
          { 'name' => 'broken', 'ns' => 0, 'type' => 'complex', 'type_ref' => '99:NonExistent' }
        ]

        corrupt_def = WSDL::Definition.from_h(base.merge('services' => services))

        # Should not raise NoMethodError — should handle missing ref gracefully
        expect { corrupt_def.operation_data('authenticate') }.not_to raise_error
      end
    end
  end

  private

  def collect_types(elements, types: {})
    elements.flat_map do |el|
      children = el['children'] || (el['type_ref'] ? types.dig(el['type_ref'], 'children') : nil) || []
      [el['type']] + collect_types(children, types:)
    end
  end

  def collect_names(elements, types: {})
    elements.flat_map do |el|
      children = el['children'] || (el['type_ref'] ? types.dig(el['type_ref'], 'children') : nil) || []
      [el['name']] + collect_names(children, types:)
    end
  end

  def collect_all_elements(elements, types: {})
    elements.flat_map do |el|
      children = el['children'] || (el['type_ref'] ? types.dig(el['type_ref'], 'children') : nil) || []
      [el] + collect_all_elements(children, types:)
    end
  end

  def find_leaf_element(elements, types: {})
    elements.each do |el|
      return el if el['type'] == 'simple'

      children = el['children'] || (el['type_ref'] ? types.dig(el['type_ref'], 'children') : nil) || []
      leaf = find_leaf_element(children, types:)
      return leaf if leaf
    end
    nil
  end

  # Recursively walks all elements from a to_h services structure,
  # including into type registry entries, returning every element hash found.
  def walk_all_elements_in_to_h(data)
    types = data['types'] || {}
    all_operations_from(data).flat_map { |op| operation_elements(op, types:) }
  end

  def all_operations_from(data)
    data['services'].each_value.flat_map { |svc|
      all_ports = svc['ports']
      all_ports.each_value.flat_map { |port|
        ops = port['operations'] || all_ports.dig(port['extends'], 'operations') || {}
        ops.each_value.flat_map { |v| v.is_a?(Array) ? v : [v] }
      }
    }
  end

  def operation_elements(operation, types: {})
    %w[input output].flat_map { |dir|
      next [] unless operation[dir]

      %w[header body].flat_map { |section| collect_all_elements(operation[dir][section] || [], types:) }
    }
  end

  # Recursively checks that no element hash in the tree contains a type_ref key.
  def assert_no_type_ref(elements)
    elements.each do |el|
      expect(el).not_to have_key('type_ref'), "Element #{el['name']} should not have type_ref after expansion"
      assert_no_type_ref(el['children']) if el['children']
    end
  end
end
