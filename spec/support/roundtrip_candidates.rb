# frozen_string_literal: true

module RoundtripCandidates
  module_function

  def type_group_for(base_type)
    local = base_type&.split(':')&.last
    WSDL::Response::TypeCoercer::TYPE_GROUPS[local]&.to_sym
  end

  def element_unsupported?(element)
    return true if element.recursive? || element.any_content?

    element.children.any? { |child| element_unsupported?(child) }
  end

  def discover_candidates
    fixture_dir = File.expand_path('../fixtures/wsdl', __dir__)
    Dir.glob("#{fixture_dir}/*")
      .select { |p| File.file?(p) }
      .flat_map { |path| candidates_from_wsdl(path) }
  end

  # Errors that legitimately prevent a WSDL or operation from being tested.
  EXPECTED_ERRORS = [
    WSDL::SchemaImportError,         # Unresolvable schema imports
    WSDL::UnsupportedStyleError,     # rpc/encoded operations
    WSDL::ResourceLimitError,        # Deeply nested types exceeding limits
    WSDL::UnresolvedReferenceError   # Missing schema elements
  ].freeze

  def candidates_from_wsdl(path)
    client = WSDL::Client.new(path)
    candidates = []

    client.services.each do |service_name, service_info|
      service_info[:ports].each_key do |port_name|
        client.operations(service_name, port_name).each do |op_name|
          candidate = build_candidate(client, service_name, port_name, op_name)
          candidates << candidate if candidate
        end
      end
    end

    candidates
  rescue *EXPECTED_ERRORS
    []
  end

  def build_candidate(client, service_name, port_name, op_name)
    operation = client.operation(service_name, port_name, op_name)

    elements = operation.contract.response.body.elements
    return if elements.empty?
    return if elements.any? { |el| element_unsupported?(el) }

    {
      label: "#{service_name}/#{port_name}/#{op_name}",
      schema_elements: elements,
      soap_version: operation.soap_version,
      output_style: operation.output_style,
      operation_name: operation.name,
      output_namespace: operation.output_namespace
    }
  rescue *EXPECTED_ERRORS
    nil
  end

  def extract_parse_node(xml, candidate)
    doc = Nokogiri::XML(xml)
    soap_ns = candidate[:soap_version] == '1.2' ? WSDL::NS::SOAP_1_2 : WSDL::NS::SOAP_1_1
    body = doc.at_xpath('//env:Body', 'env' => soap_ns)

    candidate[:output_style] == 'rpc/literal' ? body.element_children.first : body
  end

  def expected_result(hash, candidate)
    wrapper = candidate[:schema_elements].first
    wrapper.complex_type? ? { wrapper.name.to_sym => hash } : hash
  end
end
