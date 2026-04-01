# frozen_string_literal: true

RSpec.describe WSDL::Definition::TypeCompactor do
  # Builds a minimal services hash where namespace values are already integers
  # (post-NamespaceCompactor). Accepts element arrays for body, output, and header.
  def build_services(elements:, output: nil, header: [], operations: nil)
    ops = operations || { 'Op' => build_operation(elements:, output:, header:) }

    {
      'Svc' => { 'ports' => { 'Port' => {
        'type' => 0, 'endpoint' => 'http://x',
        'operations' => ops
      }.freeze }.freeze }.freeze
    }
  end

  def build_operation(elements:, output: nil, header: [])
    op = {
      'name' => 'Op', 'input_name' => nil,
      'soap_action' => nil, 'soap_version' => '1.1',
      'input_style' => 'document/literal', 'output_style' => nil,
      'rpc_input_namespace' => nil, 'rpc_output_namespace' => nil,
      'schema_complete' => true,
      'input' => { 'header' => header, 'body' => elements },
      'output' => output
    }
    op.freeze
  end

  let(:namespaces) { ['http://example.com'] }

  def dig_element(compacted, index = 0, section: :body)
    compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op', 'input', section.to_s, index)
  end

  describe '.call' do
    it 'extracts typed elements into a registry' do
      child = { 'name' => 'user', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      elements = [{
        'name' => 'login', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:UserType',
        'children' => [child]
      }]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      expect(types).to have_key('0:UserType')
      expect(types['0:UserType']['children']).to eq([child])

      element = dig_element(compacted)
      expect(element['type_ref']).to eq('0:UserType')
      expect(element).not_to have_key('children')
      expect(element).not_to have_key('complex_type_id')
      expect(element).not_to have_key('attributes')
    end

    it 'preserves anonymous complex elements inline' do
      child = { 'name' => 'field', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      elements = [{
        'name' => 'wrapper', 'ns' => 0, 'type' => 'complex',
        'children' => [child]
      }]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      expect(types).to be_empty

      element = dig_element(compacted)
      expect(element['children']).to eq([child])
      expect(element).not_to have_key('type_ref')
    end

    it 'preserves simple elements unchanged' do
      original = { 'name' => 'age', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:int' }
      services = build_services(elements: [original])

      types, compacted = described_class.call(services, namespaces)

      expect(types).to be_empty

      element = dig_element(compacted)
      expect(element['name']).to eq('age')
      expect(element['type']).to eq('simple')
      expect(element['xsd_type']).to eq('xsd:int')
      expect(element).not_to have_key('type_ref')
    end

    it 'deduplicates shared types' do
      child = { 'name' => 'name', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      elements = [
        {
          'name' => 'first', 'ns' => 0, 'type' => 'complex',
          'complex_type_id' => 'http://example.com:UserType',
          'children' => [child]
        },
        {
          'name' => 'second', 'ns' => 0, 'type' => 'complex',
          'complex_type_id' => 'http://example.com:UserType',
          'children' => [child]
        }
      ]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      expect(types.size).to eq(1)
      expect(types).to have_key('0:UserType')

      first = dig_element(compacted, 0)
      second = dig_element(compacted, 1)
      expect(first['type_ref']).to eq('0:UserType')
      expect(second['type_ref']).to eq('0:UserType')
      expect(first).not_to have_key('children')
      expect(second).not_to have_key('children')
    end

    it 'stores attributes in registry when present' do
      child = { 'name' => 'value', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      attrs = [{ 'name' => 'id', 'type' => 'xsd:int' }]
      elements = [{
        'name' => 'item', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:ItemType',
        'children' => [child],
        'attributes' => attrs
      }]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      expect(types['0:ItemType']['children']).to eq([child])
      expect(types['0:ItemType']['attributes']).to eq(attrs)

      element = dig_element(compacted)
      expect(element).not_to have_key('children')
      expect(element).not_to have_key('attributes')
    end

    it 'omits attributes from registry when absent' do
      child = { 'name' => 'value', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      elements = [{
        'name' => 'item', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:ItemType',
        'children' => [child]
      }]
      services = build_services(elements:)

      types, _compacted = described_class.call(services, namespaces)

      expect(types['0:ItemType']).not_to have_key('attributes')
    end

    it 'compacts nested typed children depth-first' do
      inner_child = { 'name' => 'qty', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:int' }
      child_element = {
        'name' => 'line_item', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:ItemType',
        'children' => [inner_child]
      }
      elements = [{
        'name' => 'order', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:OrderType',
        'children' => [child_element]
      }]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      expect(types).to have_key('0:OrderType')
      expect(types).to have_key('0:ItemType')

      # Parent's registry children should reference the child type via type_ref
      parent_children = types['0:OrderType']['children']
      expect(parent_children.first['type_ref']).to eq('0:ItemType')
      expect(parent_children.first).not_to have_key('children')

      # Child type's registry entry should have the actual inline children
      expect(types['0:ItemType']['children']).to eq([inner_child])

      element = dig_element(compacted)
      expect(element['type_ref']).to eq('0:OrderType')
      expect(element).not_to have_key('children')
    end

    it 'handles overloaded operations (Array entries)' do
      child_a = { 'name' => 'a', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      child_b = { 'name' => 'b', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:int' }

      op_a = build_operation(elements: [{
        'name' => 'reqA', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:TypeA',
        'children' => [child_a]
      }])

      op_b = build_operation(elements: [{
        'name' => 'reqB', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:TypeB',
        'children' => [child_b]
      }])

      services = build_services(operations: { 'Op' => [op_a, op_b] }, elements: [])

      types, compacted = described_class.call(services, namespaces)

      expect(types).to have_key('0:TypeA')
      expect(types).to have_key('0:TypeB')

      ops = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op')
      expect(ops).to be_an(Array)
      expect(ops[0].dig('input', 'body', 0, 'type_ref')).to eq('0:TypeA')
      expect(ops[1].dig('input', 'body', 0, 'type_ref')).to eq('0:TypeB')
    end

    it 'handles output messages' do
      child = { 'name' => 'result', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      output_msg = {
        'header' => [],
        'body' => [{
          'name' => 'response', 'ns' => 0, 'type' => 'complex',
          'complex_type_id' => 'http://example.com:ResponseType',
          'children' => [child]
        }]
      }
      services = build_services(elements: [], output: output_msg)

      types, compacted = described_class.call(services, namespaces)

      expect(types).to have_key('0:ResponseType')

      output_element = compacted.dig('Svc', 'ports', 'Port', 'operations', 'Op', 'output', 'body', 0)
      expect(output_element['type_ref']).to eq('0:ResponseType')
      expect(output_element).not_to have_key('children')
    end

    it 'handles header elements' do
      child = { 'name' => 'token', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      header_elements = [{
        'name' => 'auth', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'http://example.com:AuthHeader',
        'children' => [child]
      }]
      services = build_services(elements: [], header: header_elements)

      types, compacted = described_class.call(services, namespaces)

      expect(types).to have_key('0:AuthHeader')

      header_element = dig_element(compacted, 0, section: :header)
      expect(header_element['type_ref']).to eq('0:AuthHeader')
      expect(header_element).not_to have_key('children')
    end

    it 'handles complex_type_id with no colon (bare name) without raising' do
      child = { 'name' => 'x', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
      elements = [{
        'name' => 'Broken', 'ns' => 0, 'type' => 'complex',
        'complex_type_id' => 'BareTypeName',
        'children' => [child]
      }]
      services = build_services(elements:)

      types, compacted = described_class.call(services, namespaces)

      element = dig_element(compacted)
      expect(element['type_ref']).to eq('BareTypeName')
      expect(element).not_to have_key('children')
      expect(types).to have_key('BareTypeName')
    end

    context 'with element_ref_id (anonymous complex types on ref\'d elements)' do
      it 'deduplicates elements with the same element_ref_id' do
        child = { 'name' => 'value', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }

        op_a = build_operation(elements: [{
          'name' => 'Items', 'ns' => 0, 'type' => 'complex',
          'element_ref_id' => 'http://example.com:Items',
          'children' => [child]
        }])

        op_b = build_operation(elements: [{
          'name' => 'Items', 'ns' => 0, 'type' => 'complex',
          'element_ref_id' => 'http://example.com:Items',
          'children' => [child]
        }])

        services = build_services(operations: { 'OpA' => op_a, 'OpB' => op_b }, elements: [])

        types, compacted = described_class.call(services, namespaces)

        expect(types).to have_key('e:0:Items')
        expect(types['e:0:Items']['children']).to eq([child])

        el_a = compacted.dig('Svc', 'ports', 'Port', 'operations', 'OpA', 'input', 'body', 0)
        el_b = compacted.dig('Svc', 'ports', 'Port', 'operations', 'OpB', 'input', 'body', 0)
        expect(el_a['type_ref']).to eq('e:0:Items')
        expect(el_b['type_ref']).to eq('e:0:Items')
        expect(el_a).not_to have_key('children')
        expect(el_b).not_to have_key('children')
      end

      it 'does not collide named type and element ref with same local name' do
        type_child = { 'name' => 'a', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
        ref_child = { 'name' => 'b', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:int' }

        elements = [
          {
            'name' => 'typed', 'ns' => 0, 'type' => 'complex',
            'complex_type_id' => 'http://example.com:Foo',
            'children' => [type_child]
          },
          {
            'name' => 'reffed', 'ns' => 0, 'type' => 'complex',
            'element_ref_id' => 'http://example.com:Foo',
            'children' => [ref_child]
          }
        ]
        services = build_services(elements:)

        types, _compacted = described_class.call(services, namespaces)

        expect(types).to have_key('0:Foo')
        expect(types).to have_key('e:0:Foo')
        expect(types['0:Foo']['children']).to eq([type_child])
        expect(types['e:0:Foo']['children']).to eq([ref_child])
      end

      it 'removes element_ref_id from compacted output' do
        child = { 'name' => 'x', 'ns' => 0, 'type' => 'simple', 'xsd_type' => 'xsd:string' }
        elements = [{
          'name' => 'Items', 'ns' => 0, 'type' => 'complex',
          'element_ref_id' => 'http://example.com:Items',
          'children' => [child]
        }]
        services = build_services(elements:)

        _types, compacted = described_class.call(services, namespaces)

        element = dig_element(compacted)
        expect(element).not_to have_key('element_ref_id')
        expect(element).to have_key('type_ref')
      end

      it 'does not compact simple-type ref\'d elements but strips element_ref_id' do
        elements = [{
          'name' => 'Id', 'ns' => 0, 'type' => 'simple',
          'element_ref_id' => 'http://example.com:Id',
          'xsd_type' => 'xsd:string'
        }]
        services = build_services(elements:)

        types, compacted = described_class.call(services, namespaces)

        expect(types).to be_empty

        element = dig_element(compacted)
        expect(element).not_to have_key('type_ref')
        expect(element).not_to have_key('element_ref_id')
      end

      it 'strips element_ref_id from simple elements' do
        elements = [{
          'name' => 'Code', 'ns' => 0, 'type' => 'simple',
          'element_ref_id' => 'http://example.com:Code',
          'xsd_type' => 'xsd:int'
        }]
        services = build_services(elements:)

        _types, compacted = described_class.call(services, namespaces)

        element = dig_element(compacted)
        expect(element['name']).to eq('Code')
        expect(element['xsd_type']).to eq('xsd:int')
        expect(element).not_to have_key('element_ref_id')
      end

      it 'does not register recursive elements with element_ref_id but strips the key' do
        elements = [{
          'name' => 'Node', 'ns' => 0, 'type' => 'recursive',
          'recursive_type' => 'tns:Node',
          'element_ref_id' => 'http://example.com:Node'
        }]
        services = build_services(elements:)

        types, compacted = described_class.call(services, namespaces)

        element = dig_element(compacted)
        expect(element).not_to have_key('type_ref')
        expect(element).not_to have_key('element_ref_id')
        expect(element['type']).to eq('recursive')
        expect(element['recursive_type']).to eq('tns:Node')

        # Recursive label is recorded but NOT under an element-ref key
        # because the element is not registered in the type registry
        labels = types['_recursive_labels']
        expect(labels).to have_key('e:0:Node')
        expect(labels['e:0:Node']).to eq('tns:Node')
      end

      it 'records recursive labels for element-ref types' do
        elements = [{
          'name' => 'Items', 'ns' => 0, 'type' => 'complex',
          'element_ref_id' => 'http://example.com:Items',
          'children' => [
            { 'name' => 'Item', 'ns' => 0, 'type' => 'recursive', 'recursive_type' => 'tns:Items',
              'element_ref_id' => 'http://example.com:Items' }
          ]
        }]
        services = build_services(elements:)

        types, _compacted = described_class.call(services, namespaces)

        labels = types['_recursive_labels']
        expect(labels).to have_key('e:0:Items')
        expect(labels['e:0:Items']).to eq('tns:Items')
      end
    end
  end
end
