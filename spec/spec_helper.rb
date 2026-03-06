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

if ENV['GRAPH']
  require 'rubydeps'
  Rubydeps.start
end

ENV['RANTLY_VERBOSE'] ||= '0'

require 'equivalent-xml'
require 'equivalent-xml/rspec_matchers'

support_files = File.expand_path('spec/support/**/*.rb')
Dir[support_files].each do |file|
  require file
end

RSpec.configure do |config|
  config.include SpecSupport
  config.mock_with :rspec
  config.order = 'random'

  # Reset global state to prevent test pollution.
  config.before do
    WSDL.cache = nil
    WSDL.logger = nil
  end
end
