# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

# syslog was removed from default gems in Ruby 3.4
gem 'syslog' if RUBY_VERSION >= '3.4'

# benchmark was removed from default gems in Ruby 4.0 (silence warning on 3.4+)
gem 'benchmark' if RUBY_VERSION >= '3.4'

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
  gem 'simplecov', '~> 0.22', require: false
  gem 'yard', require: false
  gem 'yard-markdown-relative-links', require: false
end
