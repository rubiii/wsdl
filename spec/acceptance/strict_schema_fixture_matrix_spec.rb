# frozen_string_literal: true

RSpec.describe 'Strict schema fixture matrix' do
  let(:strict_supported_fixtures) do
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

  let(:relaxed_only_fixtures) do
    {
      'wsdl/juniper' => WSDL::SchemaImportError
    }
  end

  let(:sandbox_required_fixtures) do
    [
      'wsdl/travelport/system_v32_0/System.wsdl'
    ]
  end

  it 'loads strict-supported fixtures in both strict and relaxed modes' do
    strict_supported_fixtures.each do |fixture_key|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: true)
      }.not_to raise_error, "expected strict mode to parse #{fixture_key}"

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: false)
      }.not_to raise_error, "expected relaxed mode to parse #{fixture_key}"
    end
  end

  it 'requires relaxed mode for fixtures with recoverable schema import failures' do
    relaxed_only_fixtures.each do |fixture_key, strict_error|
      wsdl_path = fixture(fixture_key)

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: true)
      }.to raise_error(strict_error), "expected strict mode to fail for #{fixture_key}"

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: false)
      }.not_to raise_error, "expected relaxed mode to parse #{fixture_key}"
    end
  end

  it 'enforces sandbox configuration for fixtures with sibling relative imports' do
    sandbox_required_fixtures.each do |fixture_key|
      wsdl_path = fixture(fixture_key)
      strict_message = "expected strict mode to fail without sandbox_paths for #{fixture_key}"
      relaxed_message = "expected relaxed mode to fail without sandbox_paths for #{fixture_key}"

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: true)
      }.to raise_error(WSDL::PathRestrictionError), strict_message

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: false)
      }.to raise_error(WSDL::PathRestrictionError), relaxed_message

      system_dir = File.dirname(File.expand_path(wsdl_path))
      common_dir = File.expand_path('../common_v32_0', system_dir)
      sandbox_paths = [system_dir, common_dir]

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: true, sandbox_paths:)
      }.not_to raise_error, "expected strict mode to parse #{fixture_key} when sandbox_paths are set"

      expect {
        WSDL::Client.new(wsdl_path, cache: false, strict_schema: false, sandbox_paths:)
      }.not_to raise_error, "expected relaxed mode to parse #{fixture_key} when sandbox_paths are set"
    end
  end
end
