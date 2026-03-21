# frozen_string_literal: true

require 'bundler'
Bundler.setup(:default, :development)

unless RUBY_PLATFORM =~ /java/
  require 'simplecov'

  SimpleCov.start do
    add_filter('spec')
    enable_coverage(:branch)

    minimum_coverage line: 95, branch: 80
    minimum_coverage_by_file 80

    add_group 'Security', 'lib/wsdl/security'
    add_group 'Parser',   'lib/wsdl/parser'
    add_group 'Request',  'lib/wsdl/request'
    add_group 'Response', 'lib/wsdl/response'
    add_group 'XML',      'lib/wsdl/xml'
  end
end

require 'wsdl'

if ENV.fetch('DEBUG', nil)
  require 'logger'
  WSDL.logger = Logger.new($stdout, level: Logger::DEBUG)
end

ENV['RANTLY_VERBOSE'] ||= '0'

require 'equivalent-xml'
require 'equivalent-xml/rspec_matchers'
require 'webmock/rspec'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each do |f|
  require f
end

Dir[File.join(__dir__, 'fixtures', 'services', '*.rb')].each do |f|
  require f
end

RSpec.configure do |config|
  config.include SpecSupport

  config.disable_monkey_patching!
  config.order = :random
  config.warnings = true
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end

  # Reset global state to prevent test pollution.
  config.before do
    WSDL.cache = nil
    WSDL.logger = nil
  end
end
