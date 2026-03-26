# frozen_string_literal: true

require 'yaml'

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

  # Errors that legitimately prevent a WSDL or operation from being tested.
  EXPECTED_ERRORS = [
    WSDL::SchemaImportError,         # Unresolvable schema imports
    WSDL::UnsupportedStyleError,     # rpc/encoded operations
    WSDL::ResourceLimitError,        # Deeply nested types exceeding limits
    WSDL::UnresolvedReferenceError,  # Missing schema elements
    WSDL::OperationOverloadError     # Overloaded operations (strict mode)
  ].freeze

  # ============================================================
  # Candidate discovery
  # ============================================================

  def discover_candidates
    discover_local_candidates + discover_remote_candidates
  end

  def discover_local_candidates
    fixture_dir = File.expand_path('../fixtures/wsdl', __dir__)
    Dir.glob("#{fixture_dir}/*")
      .select { |p| File.file?(p) }
      .flat_map { |path| candidates_from_local(path) }
  end

  def candidates_from_local(path)
    client = WSDL::Client.new(WSDL.parse(path))

    # Skip fixtures with build issues (unresolvable types, missing elements,
    # resource limits). These operations have incomplete element trees that
    # can't round-trip through Builder → Parser correctly.
    return [] if client.definition.build_issues.any?

    candidates_from_client(client)
  rescue *EXPECTED_ERRORS
    []
  end

  def discover_remote_candidates
    fixture_dir = File.expand_path('../fixtures/wsdl', __dir__)
    Dir.glob("#{fixture_dir}/*/manifest.yml")
      .flat_map { |path| candidates_from_manifest(path) }
  end

  def candidates_from_manifest(manifest_path)
    client = mock_client_from_manifest(manifest_path, SpecSupport::HTTPMock.new)
    candidates_from_client(client)
  rescue *EXPECTED_ERRORS
    []
  end

  def mock_client_from_manifest(manifest_path, http_mock)
    config = YAML.safe_load_file(manifest_path)
    dir = File.dirname(manifest_path)
    fixture_name = File.basename(dir)

    if config['mappings']
      config['mappings'].each do |url, file|
        http_mock.fake_request(url, "wsdl/#{fixture_name}/#{file}")
      end
      WSDL::Client.new(WSDL.parse(config['entry_url'], http: http_mock), http: http_mock)
    else
      entry = File.join(dir, config['entry_path'])
      parse_options = { http: http_mock }
      parse_options[:sandbox_paths] = [dir] if config['sandbox']
      WSDL::Client.new(WSDL.parse(entry, **parse_options), http: http_mock)
    end
  end

  def candidates_from_client(client)
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

  # ============================================================
  # Round-trip helpers
  # ============================================================

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
