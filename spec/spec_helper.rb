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

if (logger_to_enable = ENV.fetch('DEBUG', nil))
  logger = Logging.logger[logger_to_enable]
  logger.add_appenders(Logging.appenders.stdout)
  logger.level = :debug
end

if ENV['GRAPH']
  require 'rubydeps'
  Rubydeps.start
end

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

  # Disable caching by default to prevent test pollution.
  # Tests that specifically test caching should enable it explicitly.
  config.before do
    WSDL.cache = nil
  end
end
