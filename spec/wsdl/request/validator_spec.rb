# frozen_string_literal: true

RSpec.describe WSDL::Request::Validator do
  # -- helpers ----------------------------------------------------------------

  # rubocop:disable Metrics/ParameterLists
  def build_element(name:, namespace: nil, form: 'qualified', min_occurs: '1', max_occurs: '1',
                    children: [], attributes: [], any_content: false)
    el = WSDL::XML::Element.new
    el.name = name
    el.namespace = namespace
    el.form = form
    el.min_occurs = min_occurs
    el.max_occurs = max_occurs
    el.children = children
    el.any_content = any_content
    el.attributes = attributes unless attributes.empty?
    el
  end
  # rubocop:enable Metrics/ParameterLists

  def build_attribute(name:, use: 'required')
    attr = WSDL::XML::Attribute.new
    attr.name = name
    attr.use = use
    attr
  end

  def build_node(name, namespace_uri: nil, children: [], attributes: [])
    prefix, local = name.include?(':') ? name.split(':', 2) : [nil, name]
    node = WSDL::Request::Node.new(name:, prefix:, local_name: local, namespace_uri:)
    children.each do |c|
      node.children << c
    end
    attributes.each do |a|
      node.attributes << a
    end
    node
  end

  def build_request_attribute(name, value, namespace_uri: nil)
    prefix, local = name.include?(':') ? name.split(':', 2) : [nil, name]
    WSDL::Request::Attribute.new(name, prefix, local, value, namespace_uri)
  end

  def build_document(header: [], body: [])
    doc = WSDL::Request::Envelope.new
    header.each do |n|
      doc.header << n
    end
    body.each do |n|
      doc.body << n
    end
    doc
  end

  def build_contract(header_elements: [], body_elements: [], style: 'document/literal')
    header = WSDL::Contract::PartContract.new(header_elements, section: :header)
    body = WSDL::Contract::PartContract.new(body_elements, section: :body)
    request = WSDL::Contract::MessageContract.new(header:, body:)
    Data.define(:request, :style).new(request:, style:)
  end

  def validator(contract:, strictness: WSDL::Strictness.on, schema_complete: true)
    described_class.new(contract:, strictness:, schema_complete:)
  end

  # -- shared schema elements -------------------------------------------------

  let(:ns_example) { 'http://example.com/ns' }
  let(:ns_other) { 'http://other.com/ns' }

  # ---------------------------------------------------------------------------
  # 1. Schema completeness
  # ---------------------------------------------------------------------------
  describe 'schema completeness' do
    let(:contract) { build_contract }

    it 'raises in strict mode when schema is incomplete' do
      v = validator(contract:, strictness: WSDL::Strictness.on, schema_complete: false)
      expect { v.validate!(build_document) }.to raise_error(WSDL::RequestValidationError, /complete/)
    end

    it 'passes in strict mode when schema is complete' do
      v = validator(contract:, strictness: WSDL::Strictness.on, schema_complete: true)
      expect { v.validate!(build_document) }.not_to raise_error
    end

    it 'skips check in relaxed mode even when schema is incomplete' do
      v = validator(contract:, strictness: WSDL::Strictness.off, schema_complete: false)
      expect { v.validate!(build_document) }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Strict vs. relaxed mode interactions
  # ---------------------------------------------------------------------------
  describe 'strict vs. relaxed mode' do
    let(:expected) { build_element(name: 'Item', namespace: ns_example) }
    let(:contract) { build_contract(body_elements: [expected]) }

    context 'unknown elements' do
      let(:doc) do
        build_document(body: [
          build_node('Item', namespace_uri: ns_example),
          build_node('Unknown')
        ])
      end

      it 'raises in strict mode for unknown body element' do
        v = validator(contract:)
        expect { v.validate!(doc) }.to raise_error(WSDL::RequestValidationError, /Unknown body element/)
      end

      it 'silently skips unknown elements in relaxed mode' do
        v = validator(contract:, strictness: WSDL::Strictness.off)
        expect { v.validate!(doc) }.not_to raise_error
      end
    end

    context 'required elements' do
      let(:required) { build_element(name: 'Required', namespace: ns_example, min_occurs: '1') }
      let(:contract) { build_contract(body_elements: [required]) }
      let(:empty_doc) { build_document }

      it 'raises in strict mode when required element is missing' do
        v = validator(contract:)
        expect { v.validate!(empty_doc) }.to raise_error(WSDL::RequestValidationError, /Missing required/)
      end

      it 'skips required check in relaxed mode' do
        v = validator(contract:, strictness: WSDL::Strictness.off)
        expect { v.validate!(empty_doc) }.not_to raise_error
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Namespace resolution combinations
  # ---------------------------------------------------------------------------
  describe 'namespace resolution' do
    context 'qualified elements' do
      let(:expected) { build_element(name: 'Item', namespace: ns_example, form: 'qualified') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'passes when namespace matches' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end

      it 'auto-resolves missing namespace on qualified element' do
        node = build_node('Item')
        doc = build_document(body: [node])
        validator(contract:).validate!(doc)
        expect(node.namespace_uri).to eq(ns_example)
      end

      it 'raises in strict mode when namespace is wrong' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_other)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /namespace/)
      end

      it 'passes in relaxed mode when namespace is wrong' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_other)])
        expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
      end
    end

    context 'unqualified elements' do
      let(:expected) { build_element(name: 'Item', namespace: nil, form: 'unqualified') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'passes when node has no namespace' do
        doc = build_document(body: [build_node('Item')])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end

      it 'does not match when node has a namespace on unqualified element' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError)
      end
    end

    context 'namespace auto-resolution on nested children' do
      let(:inner) { build_element(name: 'Sub', namespace: ns_other, form: 'qualified', min_occurs: '0') }
      let(:outer) { build_element(name: 'Wrap', namespace: ns_example, form: 'qualified', children: [inner]) }
      let(:contract) { build_contract(body_elements: [outer]) }

      it 'auto-resolves missing namespace on nested qualified child' do
        sub_node = build_node('Sub')
        wrap_node = build_node('Wrap', namespace_uri: ns_example, children: [sub_node])
        doc = build_document(body: [wrap_node])
        validator(contract:).validate!(doc)
        expect(sub_node.namespace_uri).to eq(ns_other)
      end
    end

    context 'mixed qualified and unqualified in same section' do
      let(:qualified) { build_element(name: 'Alpha', namespace: ns_example, form: 'qualified') }
      let(:unqualified) { build_element(name: 'Beta', form: 'unqualified', min_occurs: '0') }
      let(:contract) { build_contract(body_elements: [qualified, unqualified]) }

      it 'validates each element according to its own form' do
        doc = build_document(body: [
          build_node('Alpha', namespace_uri: ns_example),
          build_node('Beta')
        ])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Attribute validation combinations
  # ---------------------------------------------------------------------------
  describe 'attribute validation' do
    let(:required_attr) { build_attribute(name: 'id', use: 'required') }
    let(:optional_attr) { build_attribute(name: 'lang', use: 'optional') }
    let(:expected) do
      build_element(name: 'Item', namespace: ns_example, attributes: [required_attr, optional_attr])
    end
    let(:contract) { build_contract(body_elements: [expected]) }

    it 'passes with all required attributes present' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('id', '42')
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'raises in strict mode when required attribute is missing' do
      node = build_node('Item', namespace_uri: ns_example)
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /Missing required attribute "id"/)
    end

    it 'does not raise for missing optional attributes' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('id', '1')
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'raises in strict mode for unknown attributes' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('id', '1'),
        build_request_attribute('bogus', 'x')
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /Unknown attribute "bogus"/)
    end

    it 'skips unknown attribute check in relaxed mode' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('id', '1'),
        build_request_attribute('bogus', 'x')
      ])
      doc = build_document(body: [node])
      expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
    end

    it 'always allows xsi:nil attribute even in strict mode' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('id', '1'),
        build_request_attribute('xsi:nil', 'true', namespace_uri: WSDL::NS::XSI)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'skips required attribute check in relaxed mode' do
      node = build_node('Item', namespace_uri: ns_example)
      doc = build_document(body: [node])
      expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
    end

    it 'raises for missing required attribute even when optional and xsi:nil are present' do
      node = build_node('Item', namespace_uri: ns_example, attributes: [
        build_request_attribute('lang', 'en'),
        build_request_attribute('xsi:nil', 'true', namespace_uri: WSDL::NS::XSI)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /Missing required attribute "id"/)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Child ordering and occurrence constraints
  # ---------------------------------------------------------------------------
  describe 'child ordering and occurrence constraints' do
    let(:child_a) { build_element(name: 'A', namespace: ns_example, min_occurs: '1', max_occurs: '1') }
    let(:child_b) { build_element(name: 'B', namespace: ns_example, min_occurs: '0', max_occurs: '1') }
    let(:child_c) { build_element(name: 'C', namespace: ns_example, min_occurs: '1', max_occurs: '1') }
    let(:parent) do
      build_element(name: 'Parent', namespace: ns_example, children: [child_a, child_b, child_c])
    end
    let(:contract) { build_contract(body_elements: [parent]) }

    it 'passes with children in correct order' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('B', namespace_uri: ns_example),
        build_node('C', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'passes with optional child omitted' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('C', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'raises in strict mode when children are out of order' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('C', namespace_uri: ns_example),
        build_node('A', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /out of order/)
    end

    it 'skips order check in relaxed mode' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('C', namespace_uri: ns_example),
        build_node('A', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
    end

    it 'raises when required child is missing' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('B', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /Missing required child element "A"/)
    end

    it 'raises when child exceeds maxOccurs' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('A', namespace_uri: ns_example),
        build_node('C', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /exceeds maxOccurs/)
    end

    it 'ignores non-element children (TextNode, Comment, etc.)' do
      parent_node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('C', namespace_uri: ns_example)
      ])
      parent_node.children.insert(1, WSDL::Request::TextNode.new(content: 'some text'))
      parent_node.children.insert(2, WSDL::Request::Comment.new(text: 'a comment'))
      parent_node.children << WSDL::Request::CDataNode.new(content: '<raw>')
      parent_node.children << WSDL::Request::ProcessingInstruction.new(target: 'xml', content: 'version="1.0"')
      doc = build_document(body: [parent_node])
      expect { validator(contract:).validate!(doc) }.not_to raise_error
    end

    it 'raises for unknown child in strict mode without wildcard' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('C', namespace_uri: ns_example),
        build_node('Unknown')
      ])
      doc = build_document(body: [node])
      expect { validator(contract:).validate!(doc) }
        .to raise_error(WSDL::RequestValidationError, /Unknown child element "Unknown"/)
    end

    it 'skips child minOccurs and maxOccurs in relaxed mode' do
      node = build_node('Parent', namespace_uri: ns_example, children: [
        build_node('A', namespace_uri: ns_example),
        build_node('A', namespace_uri: ns_example)
      ])
      doc = build_document(body: [node])
      expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
    end

    context 'with wildcard (any_content)' do
      let(:parent) do
        build_element(name: 'Parent', namespace: ns_example,
                      children: [child_a], any_content: true)
      end
      let(:contract) { build_contract(body_elements: [parent]) }

      it 'allows unknown children when wildcard is set' do
        node = build_node('Parent', namespace_uri: ns_example, children: [
          build_node('A', namespace_uri: ns_example),
          build_node('Anything'),
          build_node('Else', namespace_uri: ns_other)
        ])
        doc = build_document(body: [node])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end

      it 'still validates known children even with wildcard' do
        child_a_with_max = build_element(name: 'A', namespace: ns_example,
                                         min_occurs: '1', max_occurs: '1')
        wildcard_parent = build_element(name: 'Parent', namespace: ns_example,
                                        children: [child_a_with_max], any_content: true)
        c = build_contract(body_elements: [wildcard_parent])

        node = build_node('Parent', namespace_uri: ns_example, children: [
          build_node('A', namespace_uri: ns_example),
          build_node('A', namespace_uri: ns_example),
          build_node('Extra')
        ])
        doc = build_document(body: [node])
        expect { validator(contract: c).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /exceeds maxOccurs/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Section-level occurrence constraints
  # ---------------------------------------------------------------------------
  describe 'section-level occurrence constraints' do
    context 'maxOccurs on body elements' do
      let(:expected) { build_element(name: 'Item', namespace: ns_example, max_occurs: '2') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'passes when count is within maxOccurs' do
        doc = build_document(body: [
          build_node('Item', namespace_uri: ns_example),
          build_node('Item', namespace_uri: ns_example)
        ])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end

      it 'skips maxOccurs check in relaxed mode' do
        doc = build_document(body: Array.new(5) { build_node('Item', namespace_uri: ns_example) })
        expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
      end

      it 'raises when count exceeds maxOccurs' do
        doc = build_document(body: [
          build_node('Item', namespace_uri: ns_example),
          build_node('Item', namespace_uri: ns_example),
          build_node('Item', namespace_uri: ns_example)
        ])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /exceeds maxOccurs=2 in body/)
      end
    end

    context 'unbounded maxOccurs' do
      let(:expected) { build_element(name: 'Item', namespace: ns_example, max_occurs: 'unbounded') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'allows any number of elements' do
        doc = build_document(body: Array.new(10) { build_node('Item', namespace_uri: ns_example) })
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end
    end

    context 'missing required header elements' do
      let(:required_header) { build_element(name: 'Auth', namespace: ns_example, min_occurs: '1') }
      let(:contract) { build_contract(header_elements: [required_header]) }

      it 'raises when required header element is missing' do
        doc = build_document
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /Missing required header element "Auth"/)
      end

      it 'passes when required header element is present' do
        doc = build_document(header: [build_node('Auth', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Namespace mismatch error messages
  # ---------------------------------------------------------------------------
  describe 'namespace mismatch error messages' do
    context 'qualified element with wrong namespace in strict mode' do
      let(:expected) { build_element(name: 'Item', namespace: ns_example, form: 'qualified') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'reports expected namespace for single candidate' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_other)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /#{Regexp.escape(ns_example.inspect)}/)
      end
    end

    context 'multiple qualified candidates with different namespaces' do
      let(:candidate_a) { build_element(name: 'Item', namespace: ns_example, form: 'qualified', min_occurs: '0') }
      let(:candidate_b) { build_element(name: 'Item', namespace: ns_other, form: 'qualified', min_occurs: '0') }
      let(:contract) { build_contract(body_elements: [candidate_a, candidate_b]) }

      it 'reports all expected namespaces' do
        wrong_ns = 'http://wrong.com/ns'
        doc = build_document(body: [build_node('Item', namespace_uri: wrong_ns)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /#{Regexp.escape(ns_example)}.*#{Regexp.escape(ns_other)}/)
      end
    end

    context 'unqualified element sent with namespace' do
      let(:expected) { build_element(name: 'Item', form: 'unqualified', min_occurs: '0') }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'reports that element must be unqualified' do
        doc = build_document(body: [build_node('Item', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /must be unqualified/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Cross-cutting combinatorial scenarios
  # ---------------------------------------------------------------------------
  describe 'cross-cutting combinations' do
    context 'nested elements with mixed namespace forms and attributes' do
      let(:inner_attr) { build_attribute(name: 'type', use: 'required') }
      let(:inner) do
        build_element(name: 'Detail', namespace: nil, form: 'unqualified',
                      min_occurs: '1', max_occurs: 'unbounded', attributes: [inner_attr])
      end
      let(:outer) do
        build_element(name: 'Order', namespace: ns_example, form: 'qualified',
                      children: [inner])
      end
      let(:contract) { build_contract(body_elements: [outer]) }

      it 'validates the full tree in strict mode' do
        detail = build_node('Detail', attributes: [build_request_attribute('type', 'rush')])
        order = build_node('Order', namespace_uri: ns_example, children: [detail])
        doc = build_document(body: [order])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end

      it 'raises for missing required attribute on nested child' do
        detail = build_node('Detail')
        order = build_node('Order', namespace_uri: ns_example, children: [detail])
        doc = build_document(body: [order])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /Missing required attribute "type"/)
      end

      it 'allows multiple unbounded children' do
        details = Array.new(5) do |i|
          build_node('Detail', attributes: [build_request_attribute('type', "t#{i}")])
        end
        order = build_node('Order', namespace_uri: ns_example, children: details)
        doc = build_document(body: [order])
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end
    end

    context 'header and body validated independently' do
      let(:header_el) { build_element(name: 'Token', namespace: ns_example, min_occurs: '1') }
      let(:body_el) { build_element(name: 'Payload', namespace: ns_example, min_occurs: '1') }
      let(:contract) { build_contract(header_elements: [header_el], body_elements: [body_el]) }

      it 'raises for missing header even when body is valid' do
        doc = build_document(body: [build_node('Payload', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /Missing required header element/)
      end

      it 'raises for missing body even when header is valid' do
        doc = build_document(header: [build_node('Token', namespace_uri: ns_example)])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError, /Missing required body element/)
      end

      it 'passes when both sections are valid' do
        doc = build_document(
          header: [build_node('Token', namespace_uri: ns_example)],
          body: [build_node('Payload', namespace_uri: ns_example)]
        )
        expect { validator(contract:).validate!(doc) }.not_to raise_error
      end
    end

    context 'relaxed mode with deeply nested structure' do
      let(:grandchild) { build_element(name: 'Value', namespace: ns_example, min_occurs: '1') }
      let(:child) { build_element(name: 'Field', namespace: ns_example, children: [grandchild]) }
      let(:root) { build_element(name: 'Root', namespace: ns_example, children: [child]) }
      let(:contract) { build_contract(body_elements: [root]) }

      it 'skips all nested validations in relaxed mode' do
        # Wrong namespace on grandchild, missing required grandchild, unknown child -- all tolerated
        field = build_node('Field', namespace_uri: ns_example, children: [
          build_node('Unknown')
        ])
        root_node = build_node('Root', namespace_uri: ns_example, children: [field])
        doc = build_document(body: [root_node])
        expect { validator(contract:, strictness: WSDL::Strictness.off).validate!(doc) }.not_to raise_error
      end

      it 'validates all nested levels in strict mode' do
        field = build_node('Field', namespace_uri: ns_example, children: [
          build_node('Unknown')
        ])
        root_node = build_node('Root', namespace_uri: ns_example, children: [field])
        doc = build_document(body: [root_node])
        expect { validator(contract:).validate!(doc) }
          .to raise_error(WSDL::RequestValidationError)
      end
    end

    context 'resolved_element is set during validation' do
      let(:expected) { build_element(name: 'Item', namespace: ns_example) }
      let(:contract) { build_contract(body_elements: [expected]) }

      it 'sets resolved_element on matched nodes' do
        node = build_node('Item', namespace_uri: ns_example)
        doc = build_document(body: [node])
        validator(contract:).validate!(doc)
        expect(node.resolved_element).to eq(expected)
      end

      it 'sets resolved_element on nested children' do
        inner_el = build_element(name: 'Sub', namespace: ns_example, min_occurs: '0')
        outer_el = build_element(name: 'Wrap', namespace: ns_example, children: [inner_el])
        c = build_contract(body_elements: [outer_el])

        sub_node = build_node('Sub', namespace_uri: ns_example)
        wrap_node = build_node('Wrap', namespace_uri: ns_example, children: [sub_node])
        doc = build_document(body: [wrap_node])
        validator(contract: c).validate!(doc)

        expect(wrap_node.resolved_element).to eq(outer_el)
        expect(sub_node.resolved_element).to eq(inner_el)
      end
    end
  end
end
