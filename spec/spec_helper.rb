# frozen_string_literal: true

require 'bundler'
Bundler.setup(:default, :development)

unless RUBY_PLATFORM =~ /java/
  require 'simplecov'

  SimpleCov.start do
    add_filter('spec')
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

support_files = File.expand_path('spec/support/**/*.rb')
Dir[support_files].each do |file|
  require file
end

RSpec.configure do |config|
  config.include SpecSupport

  config.disable_monkey_patching!
  config.order = 'random'
  config.warnings = true
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.mock_with :rspec
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset global state to prevent test pollution.
  config.before do
    WSDL.cache = nil
    WSDL.logger = nil
  end
end
