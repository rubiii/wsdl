# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

# profiling
# gem 'method_profiler', require: false
# gem 'ruby-prof',       require: false  # does not work on jruby!

# coverage
# gem 'coveralls', require: false
gem 'simplecov', '~> 0.22', require: false

if RUBY_VERSION >= '3'
  # net-smtp, net-pop and net-imap were removed from ruby standard gems
  gem 'net-imap', require: false
  gem 'net-pop', require: false
  gem 'net-smtp', require: false
  gem 'rexml'
end

if RUBY_VERSION >= '3.4'
  # syslog was removed from default gems in Ruby 3.4 (used by logging gem)
  gem 'syslog'
  # benchmark will be removed from default gems in Ruby 3.5
  gem 'benchmark'
end

# dependencies
# gem 'rubydeps',  require: false  # uses c extensions

# debugging
# gem 'debugger',  require: false

group :development do
  gem 'equivalent-xml', '~> 0.6'
  gem 'httpclient', '~> 2.9'
  gem 'rake', '~> 13.3'
  gem 'redcarpet', require: false
  gem 'rspec', '~> 3'
  gem 'rubocop', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-yard', require: false
  gem 'yard', require: false
  gem 'yard-markdown-relative-links', require: false
end
