# frozen_string_literal: true

RSpec.describe 'Strictness fixture matrix' do
  let(:fully_strict_fixtures) do
    %w[
      wsdl/amazon
      wsdl/authentication
      wsdl/awse
      wsdl/betfair
      wsdl/blz_service
      wsdl/bronto
      wsdl/crowd
      wsdl/daisycon
      wsdl/data_exchange
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

  let(:relaxed_schema_imports_fixtures) do
    {
      'wsdl/juniper' => WSDL::SchemaImportError
    }
  end

  let(:sandbox_required_fixtures) do
    [
      'wsdl/travelport/system_v32_0/System.wsdl'
    ]
  end

  it 'loads fully strict fixtures with Strictness.on' do
    fully_strict_fixtures.each do |fixture_key|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: WSDL::Strictness.on)
      }.not_to raise_error, "expected Strictness.on to parse #{fixture_key}"
    end
  end

  it 'requires relaxed schema_imports for fixtures with unresolvable imports' do
    relaxed_schema_imports_fixtures.each do |fixture_key, strict_error|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: WSDL::Strictness.on)
      }.to raise_error(strict_error), "expected Strictness.on to fail for #{fixture_key}"

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: { schema_imports: false })
      }.not_to raise_error, "expected schema_imports: false to parse #{fixture_key}"
    end
  end

  it 'enforces sandbox configuration regardless of strictness' do
    sandbox_required_fixtures.each do |fixture_key|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: WSDL::Strictness.on)
      }.to raise_error(WSDL::PathRestrictionError)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: WSDL::Strictness.off)
      }.to raise_error(WSDL::PathRestrictionError)

      system_dir = File.dirname(File.expand_path(wsdl_path))
      common_dir = File.expand_path('../common_v32_0', system_dir)
      sandbox_paths = [system_dir, common_dir]

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strictness: WSDL::Strictness.on, sandbox_paths:)
      }.not_to raise_error, "expected sandbox_paths to resolve #{fixture_key}"
    end
  end
end
