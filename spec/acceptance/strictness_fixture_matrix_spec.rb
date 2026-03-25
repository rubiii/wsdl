# frozen_string_literal: true

RSpec.describe 'Strictness fixture matrix' do
  let(:clean_fixtures) do
    %w[
      wsdl/authentication
      wsdl/betfair
      wsdl/blz_service
      wsdl/bronto
      wsdl/crowd
      wsdl/document_literal_wrapped
      wsdl/economic
      wsdl/email_verification
      wsdl/equifax
      wsdl/geotrust
      wsdl/interhome
      wsdl/iws
      wsdl/jetairways
      wsdl/jira
      wsdl/marketo
      wsdl/namespaced_actions
      wsdl/oracle
      wsdl/ratp
      wsdl/rpc_literal
      wsdl/spyne
      wsdl/stockquote
      wsdl/taxcloud
      wsdl/telefonkatalogen
      wsdl/temperature
      wsdl/xignite
      wsdl/yahoo
    ]
  end

  let(:fixtures_with_build_issues) do
    %w[wsdl/amazon wsdl/daisycon wsdl/data_exchange wsdl/awse]
  end

  let(:fixtures_with_import_errors) do
    { 'wsdl/juniper' => WSDL::SchemaImportError }
  end

  let(:sandbox_required_fixtures) do
    ['wsdl/travelport/system_v32_0/System.wsdl']
  end

  it 'parses clean fixtures without build issues' do
    clean_fixtures.each do |fixture_key|
      client = WSDL::Client.new(fixture(fixture_key))

      expect(client.definition.build_issues).to(
        be_empty,
        "expected no build issues for #{fixture_key}, got: #{client.definition.build_issues.inspect}"
      )
    end
  end

  it 'parses clean fixtures and passes verify!' do
    clean_fixtures.each do |fixture_key|
      definition = WSDL.parse(fixture(fixture_key))

      expect { definition.verify! }.not_to raise_error,
        "expected verify! to pass for #{fixture_key}"
    end
  end

  it 'records build issues for fixtures with unresolvable references' do
    fixtures_with_build_issues.each do |fixture_key|
      client = WSDL::Client.new(fixture(fixture_key))

      expect(client.definition.build_issues).not_to be_empty,
        "expected build issues for #{fixture_key}"
    end
  end

  it 'raises DefinitionError on verify! for fixtures with build issues' do
    fixtures_with_build_issues.each do |fixture_key|
      definition = WSDL.parse(fixture(fixture_key))

      expect { definition.verify! }.to raise_error(WSDL::DefinitionError),
        "expected verify! to raise for #{fixture_key}"
    end
  end

  it 'raises SchemaImportError for fixtures with unresolvable imports in strict mode' do
    fixtures_with_import_errors.each do |fixture_key, strict_error|
      expect {
        WSDL::Client.new(fixture(fixture_key), strictness: WSDL::Strictness.on)
      }.to raise_error(strict_error), "expected Strictness.on to fail for #{fixture_key}"
    end
  end

  it 'parses fixtures with import errors in lenient mode with build issues' do
    fixtures_with_import_errors.each_key do |fixture_key|
      client = WSDL::Client.new(fixture(fixture_key), strictness: WSDL::Strictness.off)

      expect(client.definition.build_issues).not_to be_empty,
        "expected build issues for #{fixture_key} in lenient mode"
    end
  end

  it 'enforces sandbox configuration regardless of strictness' do
    sandbox_required_fixtures.each do |fixture_key|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, strictness: WSDL::Strictness.on)
      }.to raise_error(WSDL::PathRestrictionError)

      expect {
        WSDL::Client.new(wsdl_path, strictness: WSDL::Strictness.off)
      }.to raise_error(WSDL::PathRestrictionError)

      system_dir = File.dirname(File.expand_path(wsdl_path))
      common_dir = File.expand_path('../common_v32_0', system_dir)

      expect {
        WSDL::Client.new(wsdl_path, sandbox_paths: [system_dir, common_dir])
      }.not_to raise_error, "expected sandbox_paths to resolve #{fixture_key}"
    end
  end
end
