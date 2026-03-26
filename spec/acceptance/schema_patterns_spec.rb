# frozen_string_literal: true

RSpec.describe 'Schema pattern coverage' do
  def roundtrip(operation, hash)
    elements = operation.contract.response.body.elements

    xml = WSDL::Response::Builder.new(
      schema_elements: elements,
      soap_version: operation.soap_version,
      output_style: operation.output_style,
      operation_name: operation.name,
      output_namespace: operation.output_namespace
    ).to_xml(hash)

    parse_node = RoundtripCandidates.extract_parse_node(xml, {
      soap_version: operation.soap_version,
      output_style: operation.output_style
    })

    WSDL::Response::Parser.parse(parse_node, schema: elements, unwrap: true)
  end

  describe 'recursive types' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/recursive_types')) }

    let(:operation) { client.operation(:GetTree) }

    it 'detects recursive type and stops traversal' do
      paths = operation.contract.response.body.paths
      recursive = paths.find { |p| p[:recursive_type] }

      expect(recursive).not_to be_nil
      expect(recursive[:path]).to eq %w[GetTreeResponse node children]
      expect(recursive[:recursive_type]).to eq 'tns:TreeNode'
    end

    it 'includes non-recursive children of the type' do
      paths = operation.contract.response.body.paths
      child_names = paths.map { |p| p[:path].last }

      expect(child_names).to include('id', 'label', 'children')
    end

    it 'generates a request template' do
      template = operation.contract.request.body.template(mode: :full).to_h

      expect(template).to eq(
        GetTreeRequest: {
          rootId: 'string'
        }
      )
    end
  end

  describe 'xs:attributeGroup references' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/attribute_groups')) }

    let(:operation) { client.operation(:GetRecord) }

    it 'flattens attribute group into element attributes' do
      paths = operation.contract.response.body.paths
      response_root = paths.find { |p| p[:path] == %w[GetRecordResponse] }
      attr_names = response_root[:attributes].map { |a| a[:name] }

      expect(attr_names).to contain_exactly('createdBy', 'createdAt', 'modifiedBy')
    end

    it 'round-trips response with attributes' do
      hash = {
        _createdBy: 'admin',
        _createdAt: '2026-01-15T10:30:00Z',
        _modifiedBy: 'editor',
        name: 'Test Record',
        value: 'test-value'
      }

      result = roundtrip(operation, hash)

      expect(result[:GetRecordResponse][:name]).to eq 'Test Record'
      expect(result[:GetRecordResponse][:_createdBy]).to eq 'admin'
      expect(result[:GetRecordResponse][:_modifiedBy]).to eq 'editor'
    end
  end

  describe 'attribute simpleType derivations' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/attribute_types')) }

    let(:operation) { client.operation(:GetEvent) }

    it 'sets list flag and itemType on list-derived attributes' do
      paths = operation.contract.response.body.paths
      root = paths.find { |p| p[:path].size == 1 }
      tags = root[:attributes].find { |a| a[:name] == 'tags' }
      scores = root[:attributes].find { |a| a[:name] == 'scores' }

      expect(tags[:list]).to be true
      expect(tags[:type]).to eq 'xsd:string'
      expect(scores[:list]).to be true
      expect(scores[:type]).to eq 'xsd:int'
    end

    it 'uses first memberType for union-derived attributes' do
      paths = operation.contract.response.body.paths
      root = paths.find { |p| p[:path].size == 1 }
      code = root[:attributes].find { |a| a[:name] == 'code' }

      expect(code[:list]).to be false
      expect(code[:type]).to eq 'xsd:string'
    end

    it 'round-trips list attributes with whitespace splitting and type coercion' do
      hash = {
        _tags: %w[ruby xml soap],
        _scores: [10, 20, 30],
        _code: 'ABC',
        _status: 'active',
        title: 'Test Event'
      }

      result = roundtrip(operation, hash)
      resp = result[:GetEventResponse]

      expect(resp[:_tags]).to eq %w[ruby xml soap]
      expect(resp[:_scores]).to eq [10, 20, 30]
      expect(resp[:_code]).to eq 'ABC'
      expect(resp[:_status]).to eq 'active'
    end
  end

  describe 'xs:all compositor' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/xs_all')) }

    let(:operation) { client.operation(:GetAddress) }

    it 'collects all elements' do
      paths = operation.contract.response.body.paths
      child_names = paths.select { |p| p[:path].size == 2 }.map { |p| p[:path].last }

      expect(child_names).to contain_exactly('street', 'city', 'state', 'zip')
    end

    it 'preserves minOccurs on optional elements' do
      paths = operation.contract.response.body.paths
      state = paths.find { |p| p[:path] == %w[GetAddressResponse state] }

      expect(state[:min_occurs]).to eq '0'
    end

    it 'round-trips response data' do
      hash = {
        street: '123 Main St',
        city: 'Springfield',
        state: 'IL',
        zip: '62701'
      }

      result = roundtrip(operation, hash)

      expect(result[:GetAddressResponse][:street]).to eq '123 Main St'
      expect(result[:GetAddressResponse][:city]).to eq 'Springfield'
      expect(result[:GetAddressResponse][:state]).to eq 'IL'
      expect(result[:GetAddressResponse][:zip]).to eq '62701'
    end
  end

  describe 'xs:union simpleType' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/xs_union')) }

    let(:operation) { client.operation(:GetMeasurement) }

    it 'uses first member type as base_type' do
      paths = operation.contract.response.body.paths
      value = paths.find { |p| p[:path].last == 'value' }

      expect(value[:type]).to eq 'xsd:string'
    end

    it 'round-trips response data' do
      hash = { value: 'high', unit: 'level' }
      result = roundtrip(operation, hash)

      expect(result[:GetMeasurementResponse][:value]).to eq 'high'
      expect(result[:GetMeasurementResponse][:unit]).to eq 'level'
    end
  end

  describe 'xs:list simpleType' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/xs_list')) }

    let(:operation) { client.operation(:GetTags) }

    it 'marks list elements with list flag' do
      paths = operation.contract.response.body.paths
      tags = paths.find { |p| p[:path].last == 'tags' }

      expect(tags[:list]).to be true
      expect(tags[:type]).to eq 'xsd:string'
    end

    it 'round-trips string list values' do
      hash = { tags: %w[ruby xml soap], scores: [10, 20, 30] }
      result = roundtrip(operation, hash)

      expect(result[:GetTagsResponse][:tags]).to eq %w[ruby xml soap]
    end

    it 'round-trips integer list values with type coercion' do
      hash = { tags: %w[test], scores: [42, 99] }
      result = roundtrip(operation, hash)

      expect(result[:GetTagsResponse][:scores]).to eq [42, 99]
    end

    it 'round-trips empty lists' do
      hash = { tags: [], scores: [] }
      result = roundtrip(operation, hash)

      expect(result[:GetTagsResponse][:tags]).to eq []
      expect(result[:GetTagsResponse][:scores]).to eq []
    end
  end

  describe 'xs:choice compositor' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/xs_choice')) }

    let(:operation) { client.operation(:ProcessPayment) }

    it 'includes all choice options as children' do
      paths = operation.contract.request.body.paths
      payment_paths = paths.select { |p| p[:path].size == 3 && p[:path][1] == 'paymentMethod' }

      expect(payment_paths.map { |p| p[:path].last }).to contain_exactly('creditCard', 'bankTransfer', 'paypal')
    end

    it 'generates a request template with all choices' do
      template = operation.contract.request.body.template(mode: :full).to_h

      expect(template[:ProcessPaymentRequest][:paymentMethod]).to eq(
        creditCard: 'string',
        bankTransfer: 'string',
        paypal: 'string'
      )
    end

    it 'round-trips response data' do
      hash = {
        transactionId: 'TXN-001',
        status: 'approved'
      }

      result = roundtrip(operation, hash)

      expect(result[:ProcessPaymentResponse][:transactionId]).to eq 'TXN-001'
      expect(result[:ProcessPaymentResponse][:status]).to eq 'approved'
    end
  end

  describe 'xs:group references' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/xs_group')) }

    let(:operation) { client.operation(:GetContact) }

    it 'expands group elements into the containing type' do
      paths = operation.contract.response.body.paths
      child_names = paths.select { |p| p[:path].size == 2 }.map { |p| p[:path].last }

      expect(child_names).to eq %w[name email street city zip]
    end

    it 'round-trips response data' do
      hash = {
        name: 'Jane Doe',
        email: 'jane@example.com',
        street: '456 Oak Ave',
        city: 'Portland',
        zip: '97201'
      }

      result = roundtrip(operation, hash)

      expect(result[:GetContactResponse][:name]).to eq 'Jane Doe'
      expect(result[:GetContactResponse][:street]).to eq '456 Oak Ave'
      expect(result[:GetContactResponse][:city]).to eq 'Portland'
    end

    it 'preserves sibling elements when group ref is unresolvable in relaxed mode' do
      wsdl = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://example.com/partial"
                     targetNamespace="http://example.com/partial">
          <types>
            <xsd:schema targetNamespace="http://example.com/partial" elementFormDefault="qualified">
              <xsd:element name="Req"><xsd:complexType><xsd:sequence>
                <xsd:element name="id" type="xsd:int"/>
              </xsd:sequence></xsd:complexType></xsd:element>
              <xsd:element name="Resp"><xsd:complexType><xsd:sequence>
                <xsd:element name="name" type="xsd:string"/>
                <xsd:element name="email" type="xsd:string"/>
                <xsd:group ref="tns:MissingGroup"/>
              </xsd:sequence></xsd:complexType></xsd:element>
            </xsd:schema>
          </types>
          <message name="In"><part name="p" element="tns:Req"/></message>
          <message name="Out"><part name="p" element="tns:Resp"/></message>
          <portType name="PT">
            <operation name="Op"><input message="tns:In"/><output message="tns:Out"/></operation>
          </portType>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="Op"><soap:operation soapAction="Op"/>
              <input><soap:body use="literal"/></input>
              <output><soap:body use="literal"/></output>
            </operation>
          </binding>
          <service name="S"><port name="P" binding="tns:B">
            <soap:address location="http://example.com/test"/>
          </port></service>
        </definitions>
      XML

      file = Tempfile.new(%w[partial .wsdl])
      file.write(wsdl)
      file.close

      relaxed = WSDL::Client.new(WSDL.parse(file.path, strictness: { schema_references: false }))
      op = relaxed.operation(:Op)
      paths = op.contract.response.body.paths
      child_names = paths.select { |p| p[:path].size == 2 }.map { |p| p[:path].last }

      expect(child_names).to include('name', 'email')
    ensure
      file&.unlink
    end
  end

  describe 'abstract types with xs:extension' do
    subject(:client) { WSDL::Client.new WSDL.parse(fixture('parser/abstract_types')) }

    let(:operation) { client.operation(:GetShape) }

    it 'includes base type elements via extension' do
      paths = operation.contract.response.body.paths
      circle_paths = paths.select { |p| p[:path].size == 3 && p[:path][1] == 'circle' }

      expect(circle_paths.map { |p| p[:path].last }).to eq %w[color lineWidth radius]
    end

    it 'includes base type elements in all derived types' do
      paths = operation.contract.response.body.paths
      rect_paths = paths.select { |p| p[:path].size == 3 && p[:path][1] == 'rectangle' }

      expect(rect_paths.map { |p| p[:path].last }).to eq %w[color lineWidth width height]
    end

    it 'round-trips response data' do
      hash = {
        circle: { color: 'red', lineWidth: 2, radius: 5.0 },
        rectangle: { color: 'blue', lineWidth: 1, width: 10.0, height: 20.0 }
      }

      result = roundtrip(operation, hash)
      circle = result[:GetShapeResponse][:circle]
      rectangle = result[:GetShapeResponse][:rectangle]

      expect(circle[:color]).to eq 'red'
      expect(circle[:lineWidth]).to eq 2
      expect(circle[:radius]).to eq 5.0

      expect(rectangle[:color]).to eq 'blue'
      expect(rectangle[:width]).to eq 10.0
      expect(rectangle[:height]).to eq 20.0
    end

    it 'preserves derived type elements when extension base is unresolvable in relaxed mode' do
      wsdl = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <definitions xmlns="http://schemas.xmlsoap.org/wsdl/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                     xmlns:tns="http://example.com/ext"
                     targetNamespace="http://example.com/ext">
          <types>
            <xsd:schema targetNamespace="http://example.com/ext" elementFormDefault="qualified">
              <xsd:complexType name="Derived">
                <xsd:complexContent>
                  <xsd:extension base="tns:MissingBase">
                    <xsd:sequence>
                      <xsd:element name="ownField" type="xsd:string"/>
                    </xsd:sequence>
                  </xsd:extension>
                </xsd:complexContent>
              </xsd:complexType>
              <xsd:element name="Req"><xsd:complexType><xsd:sequence>
                <xsd:element name="id" type="xsd:int"/>
              </xsd:sequence></xsd:complexType></xsd:element>
              <xsd:element name="Resp"><xsd:complexType><xsd:sequence>
                <xsd:element name="data" type="tns:Derived"/>
              </xsd:sequence></xsd:complexType></xsd:element>
            </xsd:schema>
          </types>
          <message name="In"><part name="p" element="tns:Req"/></message>
          <message name="Out"><part name="p" element="tns:Resp"/></message>
          <portType name="PT">
            <operation name="Op"><input message="tns:In"/><output message="tns:Out"/></operation>
          </portType>
          <binding name="B" type="tns:PT">
            <soap:binding style="document" transport="http://schemas.xmlsoap.org/soap/http"/>
            <operation name="Op"><soap:operation soapAction="Op"/>
              <input><soap:body use="literal"/></input>
              <output><soap:body use="literal"/></output>
            </operation>
          </binding>
          <service name="S"><port name="P" binding="tns:B">
            <soap:address location="http://example.com/test"/>
          </port></service>
        </definitions>
      XML

      file = Tempfile.new(%w[ext .wsdl])
      file.write(wsdl)
      file.close

      relaxed = WSDL::Client.new(WSDL.parse(file.path, strictness: { schema_references: false }))
      op = relaxed.operation(:Op)
      paths = op.contract.response.body.paths
      data_children = paths.select { |p| p[:path].size == 3 && p[:path][1] == 'data' }

      expect(data_children.map { |p| p[:path].last }).to include('ownField')
    ensure
      file&.unlink
    end
  end
end
